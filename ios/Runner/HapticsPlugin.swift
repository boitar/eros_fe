import UIKit
import Flutter
import CoreHaptics

/// Native haptics bridge and progressive refresh engine.
///
/// UIKit generators are kept around so `prepare()`ed engines fire without
/// latency; the Core Haptics engine exists for the progressive
/// pull-to-refresh ticks that need per-event intensity and sharpness values
/// the fixed system styles cannot express. Haptics are decorative: every
/// failure path stays silent instead of surfacing errors.
enum ErosHaptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static var hapticEngine: CHHapticEngine?

    static func selection() {
        selectionGenerator.selectionChanged()
    }

    static func light() {
        lightImpactGenerator.impactOccurred()
    }

    static func medium() {
        mediumImpactGenerator.impactOccurred()
    }

    static func impact() { mediumImpactGenerator.impactOccurred() }
    static func heavy() { heavyImpactGenerator.impactOccurred() }
    static func success() { notificationGenerator.notificationOccurred(.success) }
    static func error() { notificationGenerator.notificationOccurred(.error) }

    /// One transient haptic with explicit intensity/sharpness in 0...1.
    /// Used by the pull-to-refresh ticks, which ramp intensity with pull
    /// distance so the motor feels progressive instead of binary.
    static func tick(intensity: Double, sharpness: Double) {
        if hapticEngine == nil {
            prepareEngine()
        }
        guard let hapticEngine else { return }
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(
                        parameterID: .hapticIntensity,
                        value: Float(min(max(intensity, 0), 1))
                    ),
                    CHHapticEventParameter(
                        parameterID: .hapticSharpness,
                        value: Float(min(max(sharpness, 0), 1))
                    ),
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try hapticEngine.start()
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Engine hiccups must never surface; the next tick retries lazily.
        }
    }

    static func prepareEngine() {
        if hapticEngine != nil {
            try? hapticEngine?.start()
            return
        }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        guard let engine = try? CHHapticEngine() else { return }
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak engine] in
            try? engine?.start()
        }
        try? engine.start()
        hapticEngine = engine
    }
}

final class ErosHapticsPlugin: NSObject, FlutterPlugin {
    private static let channelName = "eros/haptics"
    #if DEBUG
    private var acceptedPrepares = 0
    private var acceptedTicks = 0
    private var acceptedFeedback = 0
    #endif

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(ErosHapticsPlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "impact", "light", "medium", "heavy", "success", "error":
            switch call.method {
            case "impact": ErosHaptics.impact()
            case "light": ErosHaptics.light()
            case "medium": ErosHaptics.medium()
            case "heavy": ErosHaptics.heavy()
            case "success": ErosHaptics.success()
            case "error": ErosHaptics.error()
            default: break
            }
            #if DEBUG
            acceptedFeedback += 1
            #endif
            result(nil)
        case "prepare":
            #if DEBUG
            acceptedPrepares += 1
            #endif
            ErosHaptics.prepareEngine()
            result(nil)
        case "tick":
            guard let arguments = call.arguments as? [String: Any] else {
                result(FlutterError(
                    code: "invalid_arguments",
                    message: "Tick arguments are missing",
                    details: nil
                ))
                return
            }
            let intensity = (arguments["intensity"] as? NSNumber)?.doubleValue ?? 0.5
            let sharpness = (arguments["sharpness"] as? NSNumber)?.doubleValue ?? 0.5
            #if DEBUG
            acceptedTicks += 1
            #endif
            ErosHaptics.tick(intensity: intensity, sharpness: sharpness)
            result(nil)
        #if DEBUG
        case "debugState":
            result([
                "supportsHaptics": CHHapticEngine.capabilitiesForHardware().supportsHaptics,
                "acceptedPrepares": acceptedPrepares,
                "acceptedTicks": acceptedTicks,
                "acceptedFeedback": acceptedFeedback,
            ])
        #endif
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
