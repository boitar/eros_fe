import AVFoundation
import BackgroundTasks
import Flutter
import UIKit
import UserNotifications

/// Native iOS background download coordinator.
///
/// Strategy (strictly non-interrupting for music/podcasts):
/// 1. iOS 26+ (including LiveContainer builds that support #1710): user-initiated
///    foreground sessions request `BGContinuedProcessingTask` (strategy `.fail`)
///    for system Dynamic Island / Lock Screen live progress UI, guarded by a
///    session-scoped 2.5s launch handshake watchdog.
/// 2. LiveContainer without #1710 / iOS < 26 / non-user-initiated fallback:
///    silent `.playback` + `.mixWithOthers` `AVAudioSession` keep-alive that
///    strictly verifies mixable category + session activation before every play
///    and never touches `MPNowPlayingInfoCenter` or `MPRemoteCommandCenter`.
/// 3. Final safety net: `UIApplication.beginBackgroundTask` assertion bound to
///    its own task identifier so active downloads pause cleanly before suspend.
final class ErosBackgroundDownloadPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private static let methodChannelName = "eros/background-download"
    private static let eventChannelName = "eros/background-download/events"
    private static let completionNotificationId = "eros.download.finished"
    private static let continuedTaskHandshakeTimeout: TimeInterval = 2.5
    private static let continuedExpirationAckTimeout: TimeInterval = 1.5
    private static let graceExpirationAckTimeout: TimeInterval = 1.5
    private static let notificationDeliveryTimeout: TimeInterval = 1.0

    private enum ActiveMode: String {
        case idle
        case continuedProcessing = "continued_processing"
        case silentAudio = "silent_audio"
        case gracePeriod = "grace_period"
    }

    private struct PendingExpiration {
        let sessionToken: Int
        let finisher: () -> Void
    }

    private static var sharedInstance: ErosBackgroundDownloadPlugin?

    private var eventSink: FlutterEventSink?
    private let silentAudio = SilentAudioKeepAlive()
    private let bgSubmitQueue = DispatchQueue(
        label: "cn.honjow.fehv.background-download.submit",
        qos: .userInitiated
    )

    private var isSessionActive = false
    private var currentSessionToken = 0
    private var allowSilentAudioKeepAlive = true
    private var activeMode: ActiveMode = .idle

    // Type-erased `BGContinuedProcessingTask` so the class stays deployable to iOS 15.6.
    private var activeContinuedTask: AnyObject?
    private var activeContinuedSessionToken: Int?
    private var pendingContinuedTaskId: String?
    private var pendingContinuedSessionToken: Int?
    private var handshakeTimeoutWorkItem: DispatchWorkItem?
    private var continuedProcessingPermanentlyUnavailable = false

    private var graceBackgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var graceSessionToken: Int?
    private var pendingExpirations: [PendingExpiration] = []
    private var expirationAckTimeoutWorkItem: DispatchWorkItem?

    private var cachedTitle = ""
    private var cachedSubtitle = ""
    private var cachedCompletedUnits: Int64 = 0
    private var cachedTotalUnits: Int64 = 1
    private var hasRequestedNotificationAuth = false

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private var isLiveContainer: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["LC_HOME_PATH"] != nil || env["LC_GLOBAL_TWEAKS_FOLDER"] != nil {
            return true
        }
        return Bundle.main.bundlePath.contains("/LiveContainer/")
    }

    private var canAttemptContinuedProcessing: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return !isSimulator && !continuedProcessingPermanentlyUnavailable
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = sharedInstance ?? ErosBackgroundDownloadPlugin()
        sharedInstance = instance

        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    override init() {
        super.init()
        silentAudio.onInterruptionBegan = { [weak self] in
            self?.handleSilentAudioInterruptionBegan()
        }
        silentAudio.onRecoveryFailed = { [weak self] in
            self?.handleSilentAudioRecoveryFailed()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        silentAudio.stop()
        endGraceBackgroundTask()
    }

    // MARK: - FlutterStreamHandler

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        emitStatus()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - FlutterPlugin

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getStatus":
            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                DispatchQueue.main.async {
                    guard let self else {
                        result([:])
                        return
                    }
                    let authorized = settings.authorizationStatus == .authorized
                        || settings.authorizationStatus == .provisional
                        || settings.authorizationStatus == .ephemeral
                    result(self.statusPayload(notificationAuthorized: authorized))
                }
            }

        case "requestNotificationPermission":
            requestNotificationAuthorization { granted in
                result(granted)
            }

        case "startSession":
            let args = call.arguments as? [String: Any] ?? [:]
            let title = args["title"] as? String ?? "Downloading"
            let subtitle = args["subtitle"] as? String ?? ""
            let completedUnits = (args["completedUnits"] as? NSNumber)?.int64Value ?? 0
            let totalUnits = max((args["totalUnits"] as? NSNumber)?.int64Value ?? 1, 1)
            let allowSilent = args["allowSilentAudioKeepAlive"] as? Bool ?? true
            let requestNotification = args["requestNotificationPermission"] as? Bool ?? false
            let userInitiated = args["userInitiated"] as? Bool ?? true

            DispatchQueue.main.async {
                self.startSession(
                    title: title,
                    subtitle: subtitle,
                    completedUnits: completedUnits,
                    totalUnits: totalUnits,
                    allowSilentAudioKeepAlive: allowSilent,
                    requestNotificationPermission: requestNotification,
                    userInitiated: userInitiated
                )
                result(self.statusPayload(notificationAuthorized: nil))
            }

        case "updateProgress":
            let args = call.arguments as? [String: Any] ?? [:]
            let title = args["title"] as? String ?? cachedTitle
            let subtitle = args["subtitle"] as? String ?? cachedSubtitle
            let completedUnits = (args["completedUnits"] as? NSNumber)?.int64Value ?? cachedCompletedUnits
            let totalUnits = max((args["totalUnits"] as? NSNumber)?.int64Value ?? cachedTotalUnits, 1)

            DispatchQueue.main.async {
                self.updateProgress(
                    title: title,
                    subtitle: subtitle,
                    completedUnits: completedUnits,
                    totalUnits: totalUnits
                )
                result(nil)
            }

        case "finishSession":
            let args = call.arguments as? [String: Any] ?? [:]
            let success = args["success"] as? Bool ?? true
            let notifyTitle = args["notifyTitle"] as? String
            let notifyBody = args["notifyBody"] as? String
            let onlyNotifyInBackground = args["onlyNotifyInBackground"] as? Bool ?? true

            DispatchQueue.main.async {
                self.finishSession(
                    success: success,
                    notifyTitle: notifyTitle,
                    notifyBody: notifyBody,
                    onlyNotifyInBackground: onlyNotifyInBackground
                )
                result(nil)
            }

        case "acknowledgeExpiration":
            let args = call.arguments as? [String: Any]
            let ackToken = (args?["sessionToken"] as? NSNumber)?.intValue
            DispatchQueue.main.async {
                self.completePendingExpirations(matchingToken: ackToken)
                result(nil)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Session Lifecycle

    private func startSession(
        title: String,
        subtitle: String,
        completedUnits: Int64,
        totalUnits: Int64,
        allowSilentAudioKeepAlive: Bool,
        requestNotificationPermission: Bool,
        userInitiated: Bool
    ) {
        self.cachedTitle = title
        self.cachedSubtitle = subtitle
        self.cachedCompletedUnits = completedUnits
        self.cachedTotalUnits = max(totalUnits, 1)
        self.allowSilentAudioKeepAlive = allowSilentAudioKeepAlive

        if requestNotificationPermission && !hasRequestedNotificationAuth {
            hasRequestedNotificationAuth = true
            requestNotificationAuthorization(completion: nil)
        }

        if isSessionActive {
            if #available(iOS 26.0, *), activeContinuedTask != nil {
                applyProgressToContinuedTask()
                return
            }
            if pendingContinuedTaskId != nil {
                return
            }
            if activeMode == .silentAudio && allowSilentAudioKeepAlive {
                if !silentAudio.ensurePlaying() {
                    handleSilentAudioRecoveryFailed()
                }
                return
            }
        }

        currentSessionToken += 1
        let sessionToken = currentSessionToken
        isSessionActive = true

        let appState = UIApplication.shared.applicationState
        if #available(iOS 26.0, *),
           userInitiated,
           appState == .active,
           canAttemptContinuedProcessing {
            // Prepare a short grace assertion while waiting for launchHandler in
            // case the user backgrounds immediately after tapping Download.
            beginGraceBackgroundTaskIfNeeded(sessionToken: sessionToken)
            submitContinuedProcessingTask(
                title: title,
                subtitle: subtitle,
                sessionToken: sessionToken
            )
            return
        }

        activateFallbackKeepAliveIfAllowed(sessionToken: sessionToken)
    }

    private func updateProgress(
        title: String,
        subtitle: String,
        completedUnits: Int64,
        totalUnits: Int64
    ) {
        cachedTitle = title
        cachedSubtitle = subtitle
        cachedCompletedUnits = completedUnits
        cachedTotalUnits = max(totalUnits, 1)

        if #available(iOS 26.0, *), activeContinuedTask != nil {
            applyProgressToContinuedTask()
            return
        }

        if isSessionActive && activeMode == .silentAudio && allowSilentAudioKeepAlive {
            if !silentAudio.ensurePlaying() {
                handleSilentAudioRecoveryFailed()
            }
        }
    }

    private func finishSession(
        success: Bool,
        notifyTitle: String?,
        notifyBody: String?,
        onlyNotifyInBackground: Bool
    ) {
        let finishedToken = currentSessionToken
        isSessionActive = false
        cancelHandshakeWatchdog()

        if let pendingId = pendingContinuedTaskId {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: pendingId)
        }
        pendingContinuedTaskId = nil
        pendingContinuedSessionToken = nil

        // Detach old assertions immediately so a new session started during
        // notification delivery can never be clobbered, and old assertions are
        // ALWAYS completed even if currentSessionToken advances.
        var detachedContinuedTask: AnyObject?
        if activeContinuedSessionToken == finishedToken {
            detachedContinuedTask = activeContinuedTask
            activeContinuedTask = nil
            activeContinuedSessionToken = nil
            if #available(iOS 26.0, *),
               let task = detachedContinuedTask as? BGContinuedProcessingTask {
                task.expirationHandler = nil
            }
        }
        var detachedGraceId: UIBackgroundTaskIdentifier = .invalid
        if graceSessionToken == finishedToken && graceBackgroundTaskId != .invalid {
            detachedGraceId = graceBackgroundTaskId
            graceBackgroundTaskId = .invalid
            graceSessionToken = nil
        }

        let shouldPostNotification: Bool
        if let notifyTitle, !notifyTitle.isEmpty,
           let notifyBody, !notifyBody.isEmpty {
            shouldPostNotification = !onlyNotifyInBackground
                || UIApplication.shared.applicationState == .background
        } else {
            shouldPostNotification = false
        }

        let releaseDetached = { [weak self] in
            if #available(iOS 26.0, *),
               let task = detachedContinuedTask as? BGContinuedProcessingTask {
                task.setTaskCompleted(success: success)
                detachedContinuedTask = nil
            }
            if detachedGraceId != .invalid {
                let idToEnd = detachedGraceId
                detachedGraceId = .invalid
                UIApplication.shared.endBackgroundTask(idToEnd)
            }
            guard let self else { return }
            self.completePendingExpirations(matchingToken: finishedToken)
            // Only stop shared audio / set idle if no newer session has started.
            if !self.isSessionActive && self.currentSessionToken == finishedToken {
                self.silentAudio.stop()
                self.setActiveMode(.idle)
            }
        }

        if shouldPostNotification, let notifyTitle, let notifyBody {
            var released = false
            let releaseOnce = {
                guard !released else { return }
                released = true
                releaseDetached()
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.notificationDeliveryTimeout,
                execute: releaseOnce
            )
            postSilentLocalNotification(title: notifyTitle, body: notifyBody) {
                releaseOnce()
            }
        } else {
            releaseDetached()
        }
    }

    // MARK: - Channel 1: iOS 26+ BGContinuedProcessingTask

    @available(iOS 26.0, *)
    private func submitContinuedProcessingTask(
        title: String,
        subtitle: String,
        sessionToken: Int
    ) {
        let bundleId = Bundle.main.bundleIdentifier ?? "cn.honjow.fehv"
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        let identifier = "\(bundleId).download.\(suffix)"
        pendingContinuedTaskId = identifier
        pendingContinuedSessionToken = sessionToken

        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { [weak self] task in
            guard let self else {
                task.setTaskCompleted(success: false)
                return
            }
            guard let continuedTask = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            DispatchQueue.main.async {
                self.handleContinuedTaskLaunched(
                    continuedTask,
                    identifier: identifier,
                    sessionToken: sessionToken
                )
            }
        }

        guard registered else {
            pendingContinuedTaskId = nil
            pendingContinuedSessionToken = nil
            continuedProcessingPermanentlyUnavailable = true
            activateFallbackKeepAliveIfAllowed(sessionToken: sessionToken)
            return
        }

        let request = BGContinuedProcessingTaskRequest(
            identifier: identifier,
            title: title,
            subtitle: subtitle
        )
        // Fail fast if system cannot immediately run so we fall back cleanly for
        // this session without leaving stale queued requests behind.
        request.strategy = .fail

        startHandshakeWatchdog(for: identifier, sessionToken: sessionToken)

        if #available(iOS 27.0, *) {
            bgSubmitQueue.async { [weak self] in
                BGTaskScheduler.shared.submitTaskRequest(request) { error in
                    guard let error else { return }
                    DispatchQueue.main.async {
                        self?.handleContinuedTaskSubmissionFailure(
                            identifier: identifier,
                            sessionToken: sessionToken,
                            error: error
                        )
                    }
                }
            }
        } else {
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                handleContinuedTaskSubmissionFailure(
                    identifier: identifier,
                    sessionToken: sessionToken,
                    error: error
                )
            }
        }
    }

    @available(iOS 26.0, *)
    private func handleContinuedTaskLaunched(
        _ task: BGContinuedProcessingTask,
        identifier: String,
        sessionToken: Int
    ) {
        // Validate session token & identifier BEFORE mutating any state or watchdog.
        guard isSessionActive,
              currentSessionToken == sessionToken,
              pendingContinuedSessionToken == sessionToken,
              pendingContinuedTaskId == identifier else {
            task.setTaskCompleted(success: false)
            return
        }

        cancelHandshakeWatchdog()
        pendingContinuedTaskId = nil
        pendingContinuedSessionToken = nil
        activeContinuedTask = task
        activeContinuedSessionToken = sessionToken
        silentAudio.stop()
        endGraceBackgroundTask(expectedSessionToken: sessionToken)
        setActiveMode(.continuedProcessing)
        applyProgressToContinuedTask()

        task.expirationHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.handleContinuedTaskExpired(task, sessionToken: sessionToken)
            }
        }
    }

    @available(iOS 26.0, *)
    private func handleContinuedTaskExpired(
        _ task: BGContinuedProcessingTask,
        sessionToken: Int
    ) {
        guard isSessionActive,
              currentSessionToken == sessionToken,
              activeContinuedSessionToken == sessionToken,
              (activeContinuedTask as? BGContinuedProcessingTask) === task else {
            task.setTaskCompleted(success: false)
            return
        }

        // Apple does not guarantee `progress.isCancelled` distinguishes system UI
        // Stop from resource reclaim; emit an explicit reason so Dart keeps both
        // conservatively paused without silently overriding a user Stop tap.
        let reason = task.progress.isCancelled ? "user_cancelled" : "continued_task_expired"
        activeContinuedTask = nil
        activeContinuedSessionToken = nil
        isSessionActive = false
        silentAudio.stop()
        setActiveMode(.idle)

        enqueueExpirationFinisher(
            reason: reason,
            sessionToken: sessionToken,
            timeout: Self.continuedExpirationAckTimeout
        ) {
            task.setTaskCompleted(success: false)
        }
    }

    @available(iOS 26.0, *)
    private func applyProgressToContinuedTask() {
        guard let task = activeContinuedTask as? BGContinuedProcessingTask else { return }
        let total = max(cachedTotalUnits, 1)
        let completed = min(max(cachedCompletedUnits, 0), total)
        task.progress.totalUnitCount = total
        task.progress.completedUnitCount = completed
        task.updateTitle(cachedTitle, subtitle: cachedSubtitle)
    }

    private func startHandshakeWatchdog(for identifier: String, sessionToken: Int) {
        cancelHandshakeWatchdog()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.isSessionActive,
                  self.currentSessionToken == sessionToken,
                  self.pendingContinuedSessionToken == sessionToken,
                  self.pendingContinuedTaskId == identifier,
                  self.activeContinuedTask == nil else {
                return
            }
            // In LiveContainer builds without #1710, submit() may succeed while
            // launchHandler never fires. Cancel the pending request and fall back
            // for this session without permanently disabling future attempts.
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            self.pendingContinuedTaskId = nil
            self.pendingContinuedSessionToken = nil
            self.activateFallbackKeepAliveIfAllowed(sessionToken: sessionToken)
        }
        handshakeTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.continuedTaskHandshakeTimeout,
            execute: workItem
        )
    }

    private func cancelHandshakeWatchdog() {
        handshakeTimeoutWorkItem?.cancel()
        handshakeTimeoutWorkItem = nil
    }

    private func handleContinuedTaskSubmissionFailure(
        identifier: String,
        sessionToken: Int,
        error: Error
    ) {
        guard pendingContinuedSessionToken == sessionToken,
              pendingContinuedTaskId == identifier else {
            return
        }
        cancelHandshakeWatchdog()
        pendingContinuedTaskId = nil
        pendingContinuedSessionToken = nil

        let nsError = error as NSError
        if nsError.domain == BGTaskScheduler.errorDomain,
           let code = BGTaskScheduler.Error.Code(rawValue: nsError.code),
           code == .notPermitted {
            // Only `.notPermitted` (missing plist/entitlement) is permanent for
            // this install; `.unavailable` (e.g. Background App Refresh toggled
            // off) can recover while the process stays alive.
            continuedProcessingPermanentlyUnavailable = true
        }

        if isSessionActive && currentSessionToken == sessionToken {
            activateFallbackKeepAliveIfAllowed(sessionToken: sessionToken)
        }
    }

    // MARK: - Channel 2: Silent Non-Interrupting Audio Keep-Alive

    private func activateFallbackKeepAliveIfAllowed(sessionToken: Int) {
        guard isSessionActive, currentSessionToken == sessionToken else {
            setActiveMode(.idle)
            return
        }
        guard allowSilentAudioKeepAlive else {
            silentAudio.stop()
            enterGraceFallback(sessionToken: sessionToken)
            return
        }
        if silentAudio.start() {
            endGraceBackgroundTask(expectedSessionToken: sessionToken)
            setActiveMode(.silentAudio)
        } else {
            enterGraceFallback(sessionToken: sessionToken)
        }
    }

    private func handleSilentAudioInterruptionBegan() {
        guard isSessionActive, activeMode == .silentAudio else { return }
        let token = currentSessionToken
        if UIApplication.shared.applicationState == .background {
            if !beginGraceBackgroundTaskIfNeeded(sessionToken: token) {
                triggerImmediateExpiration(reason: "audio_recovery_failed", sessionToken: token)
            }
        }
    }

    private func handleSilentAudioRecoveryFailed() {
        guard isSessionActive, activeMode == .silentAudio else { return }
        let token = currentSessionToken
        silentAudio.stop()
        if UIApplication.shared.applicationState == .background {
            if !beginGraceBackgroundTaskIfNeeded(sessionToken: token) {
                triggerImmediateExpiration(reason: "audio_recovery_failed", sessionToken: token)
            } else {
                setActiveMode(.gracePeriod)
            }
        } else {
            setActiveMode(.gracePeriod)
        }
    }

    private func enterGraceFallback(sessionToken: Int) {
        setActiveMode(.gracePeriod)
        if UIApplication.shared.applicationState == .background {
            if !beginGraceBackgroundTaskIfNeeded(sessionToken: sessionToken) {
                triggerImmediateExpiration(reason: "grace_expired", sessionToken: sessionToken)
            }
        } else {
            beginGraceBackgroundTaskIfNeeded(sessionToken: sessionToken)
        }
    }

    // MARK: - Channel 3: UIApplication.beginBackgroundTask Safety Net

    @objc private func handleDidEnterBackground() {
        guard isSessionActive else { return }
        let token = currentSessionToken
        let hasActiveKeepAlive = activeContinuedTask != nil || silentAudio.isActuallyPlaying
        if !hasActiveKeepAlive {
            if !beginGraceBackgroundTaskIfNeeded(sessionToken: token) {
                triggerImmediateExpiration(reason: "grace_expired", sessionToken: token)
            }
        }
    }

    @objc private func handleWillEnterForeground() {
        if activeContinuedTask != nil || silentAudio.isActuallyPlaying {
            endGraceBackgroundTask()
        }
    }

    @discardableResult
    private func beginGraceBackgroundTaskIfNeeded(sessionToken: Int) -> Bool {
        if graceBackgroundTaskId != .invalid, graceSessionToken == sessionToken {
            return true
        }
        endGraceBackgroundTask()

        var createdTaskId: UIBackgroundTaskIdentifier = .invalid
        createdTaskId = UIApplication.shared.beginBackgroundTask(
            withName: "eros.download.grace.\(sessionToken)"
        ) { [weak self] in
            DispatchQueue.main.async {
                guard let self else {
                    if createdTaskId != .invalid {
                        UIApplication.shared.endBackgroundTask(createdTaskId)
                    }
                    return
                }
                let expiredId = createdTaskId
                let isCurrentGrace = self.graceBackgroundTaskId == expiredId
                    && self.graceSessionToken == sessionToken
                if isCurrentGrace {
                    self.graceBackgroundTaskId = .invalid
                    self.graceSessionToken = nil
                }

                guard isCurrentGrace,
                      self.isSessionActive,
                      self.currentSessionToken == sessionToken,
                      self.activeContinuedTask == nil,
                      !self.silentAudio.isActuallyPlaying else {
                    if expiredId != .invalid {
                        UIApplication.shared.endBackgroundTask(expiredId)
                    }
                    return
                }

                self.isSessionActive = false
                self.cancelHandshakeWatchdog()
                if let pendingId = self.pendingContinuedTaskId,
                   self.pendingContinuedSessionToken == sessionToken {
                    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: pendingId)
                    self.pendingContinuedTaskId = nil
                    self.pendingContinuedSessionToken = nil
                }
                self.silentAudio.stop()
                self.setActiveMode(.idle)
                self.enqueueExpirationFinisher(
                    reason: "grace_expired",
                    sessionToken: sessionToken,
                    timeout: Self.graceExpirationAckTimeout
                ) {
                    if expiredId != .invalid {
                        UIApplication.shared.endBackgroundTask(expiredId)
                    }
                }
            }
        }

        guard createdTaskId != .invalid else {
            return false
        }
        graceBackgroundTaskId = createdTaskId
        graceSessionToken = sessionToken
        if activeMode == .idle {
            setActiveMode(.gracePeriod)
        }
        return true
    }

    private func endGraceBackgroundTask(expectedSessionToken: Int? = nil) {
        if let expectedSessionToken, graceSessionToken != expectedSessionToken {
            return
        }
        guard graceBackgroundTaskId != .invalid else { return }
        let taskId = graceBackgroundTaskId
        graceBackgroundTaskId = .invalid
        graceSessionToken = nil
        UIApplication.shared.endBackgroundTask(taskId)
    }

    private func triggerImmediateExpiration(reason: String, sessionToken: Int) {
        guard isSessionActive, currentSessionToken == sessionToken else { return }
        isSessionActive = false
        cancelHandshakeWatchdog()
        silentAudio.stop()
        endGraceBackgroundTask(expectedSessionToken: sessionToken)
        setActiveMode(.idle)
        emitEvent([
            "type": "expired",
            "reason": reason,
            "sessionToken": sessionToken,
        ])
    }

    private func enqueueExpirationFinisher(
        reason: String,
        sessionToken: Int,
        timeout: TimeInterval,
        finisher: @escaping () -> Void
    ) {
        pendingExpirations.append(PendingExpiration(sessionToken: sessionToken, finisher: finisher))
        emitEvent([
            "type": "expired",
            "reason": reason,
            "sessionToken": sessionToken,
        ])

        expirationAckTimeoutWorkItem?.cancel()
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.completePendingExpirations(matchingToken: nil)
        }
        expirationAckTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + timeout,
            execute: timeoutWorkItem
        )
    }

    private func completePendingExpirations(matchingToken: Int?) {
        if matchingToken == nil {
            expirationAckTimeoutWorkItem?.cancel()
            expirationAckTimeoutWorkItem = nil
            let entries = pendingExpirations
            pendingExpirations.removeAll()
            for entry in entries {
                entry.finisher()
            }
            return
        }

        let toFinish = pendingExpirations.filter { $0.sessionToken == matchingToken }
        pendingExpirations.removeAll { $0.sessionToken == matchingToken }
        if pendingExpirations.isEmpty {
            expirationAckTimeoutWorkItem?.cancel()
            expirationAckTimeoutWorkItem = nil
        }
        for entry in toFinish {
            entry.finisher()
        }
    }

    // MARK: - Notifications & Events

    private func requestNotificationAuthorization(completion: ((Bool) -> Void)?) {
        // Request alert + badge only (no sound) so completion notices never duck
        // or interrupt external music/podcast playback.
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge]
        ) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    private func postSilentLocalNotification(
        title: String,
        body: String,
        completion: @escaping () -> Void
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: Self.completionNotificationId,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    private func setActiveMode(_ mode: ActiveMode) {
        guard activeMode != mode else { return }
        activeMode = mode
        emitStatus()
    }

    private func statusPayload(notificationAuthorized: Bool?) -> [String: Any] {
        var payload: [String: Any] = [
            "type": "status",
            "isLiveContainer": isLiveContainer,
            "supportsContinuedProcessing": canAttemptContinuedProcessing,
            "activeMode": activeMode.rawValue,
            "isSessionActive": isSessionActive,
        ]
        if let notificationAuthorized {
            payload["notificationAuthorized"] = notificationAuthorized
        }
        return payload
    }

    private func emitStatus() {
        emitEvent(statusPayload(notificationAuthorized: nil))
    }

    private func emitEvent(_ payload: [String: Any]) {
        guard let eventSink else { return }
        if Thread.isMainThread {
            eventSink(payload)
        } else {
            DispatchQueue.main.async {
                eventSink(payload)
            }
        }
    }
}

/// Strictly non-interrupting silent audio keep-alive.
///
/// Guarantees `.playback` + `.mixWithOthers` is configured AND activated before
/// every `play()` call, tracks owned audio session activation independently from
/// player creation, never touches `MPNowPlayingInfoCenter` or
/// `MPRemoteCommandCenter`, and handles interruptions, route changes, and media
/// service resets.
private final class SilentAudioKeepAlive {
    private var player: AVAudioPlayer?
    private var desiredActive = false
    private var audioSessionActivated = false
    private var observers: [NSObjectProtocol] = []
    private lazy var silentWavData: Data = Self.makeSilentWavData()

    var onInterruptionBegan: (() -> Void)?
    var onRecoveryFailed: (() -> Void)?

    var isActuallyPlaying: Bool {
        desiredActive && audioSessionActivated && (player?.isPlaying == true)
    }

    init() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleAudioInterruption(notification)
            }
        )
        observers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleRouteChange(notification)
            }
        )
        observers.append(
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleMediaServicesReset(notification)
            }
        )
    }

    deinit {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        stop()
    }

    @discardableResult
    func start() -> Bool {
        desiredActive = true
        return ensurePlaying()
    }

    @discardableResult
    func ensurePlaying() -> Bool {
        guard desiredActive else { return false }
        if isActuallyPlaying {
            return true
        }
        guard configureAndActivateMixableSession() else {
            return false
        }
        do {
            let audioPlayer: AVAudioPlayer
            if let existing = player {
                audioPlayer = existing
            } else {
                let created = try AVAudioPlayer(data: silentWavData)
                created.numberOfLoops = -1
                created.volume = 0.0
                created.prepareToPlay()
                player = created
                audioPlayer = created
            }

            guard audioPlayer.play() else {
                player = nil
                deactivateSessionIfOwned()
                return false
            }
            return true
        } catch {
            player = nil
            deactivateSessionIfOwned()
            return false
        }
    }

    func stop() {
        desiredActive = false
        player?.stop()
        player = nil
        deactivateSessionIfOwned()
    }

    private func configureAndActivateMixableSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            audioSessionActivated = true
            return true
        } catch {
            audioSessionActivated = false
            return false
        }
    }

    private func deactivateSessionIfOwned() {
        guard audioSessionActivated else { return }
        audioSessionActivated = false
        // Do not pass `.notifyOthersOnDeactivation` because `.mixWithOthers`
        // never pauses other apps' audio.
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard desiredActive,
              let userInfo = notification.userInfo,
              let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }
        switch type {
        case .began:
            player?.pause()
            audioSessionActivated = false
            onInterruptionBegan?()
        case .ended:
            if !ensurePlaying() {
                onRecoveryFailed?()
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard desiredActive,
              let userInfo = notification.userInfo,
              let rawReason = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
            return
        }
        if reason == .oldDeviceUnavailable && !isActuallyPlaying {
            if !ensurePlaying() {
                onRecoveryFailed?()
            }
        }
    }

    private func handleMediaServicesReset(_ notification: Notification) {
        player = nil
        audioSessionActivated = false
        guard desiredActive else { return }
        if !ensurePlaying() {
            onRecoveryFailed?()
        }
    }

    /// Generates a minimal 1-second silent mono 16-bit PCM WAV buffer at 8 kHz.
    private static func makeSilentWavData() -> Data {
        let sampleRate: UInt32 = 8000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let dataSize: UInt32 = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let byteRate: UInt32 = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign: UInt16 = channels * (bitsPerSample / 8)
        let chunkSize: UInt32 = 36 + dataSize

        var data = Data(capacity: Int(44 + dataSize))
        func appendLE<T: FixedWidthInteger>(_ value: T) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        appendLE(chunkSize)
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        appendLE(UInt32(16))
        appendLE(UInt16(1)) // PCM
        appendLE(channels)
        appendLE(sampleRate)
        appendLE(byteRate)
        appendLE(blockAlign)
        appendLE(bitsPerSample)
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        appendLE(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }
}
