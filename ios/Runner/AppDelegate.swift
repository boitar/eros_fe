import UIKit
import Flutter
#if !EROS_SIMULATOR_UI_TEST
import flutter_downloader
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        #if !EROS_SIMULATOR_UI_TEST
        FlutterDownloaderPlugin.setPluginRegistrantCallback(registerPlugins)
        #endif
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ErosPhotoLibrary") {
            ErosPhotoLibraryPlugin.register(with: registrar)
        }
        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ErosHaptics") {
            ErosHapticsPlugin.register(with: registrar)
        }
        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ErosSharePlugin") {
            ErosSharePlugin.register(with: registrar)
        }
        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ErosAppearance") {
            ErosAppearancePlugin.register(with: registrar)
        }
        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ErosLiquidGlass") {
            ErosLiquidGlassPlugin.register(with: registrar)
        }
        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ErosMenu") {
            ErosMenuPlugin.register(with: registrar)
        }
        ErosAdaptiveEnvironmentPlugin.register(with: engineBridge.pluginRegistry.registrar(
            forPlugin: "ErosAdaptiveEnvironment"
        )!)
    }

    @objc func step(displaylink: CADisplayLink) {
        // Will be called once a frame has been built while matching desired frame rate
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        print("applicationDidEnterBackground")
        addBlurEffect()
    }

//    override func applicationWillResignActive(_ application: UIApplication) {
//        print("applicationWillResignActive")
//        addBlurEffect()
//    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        print("applicationDidBecomeActive")
        SecurityBlurEffect.removeBlurEffect()
        ErosAppearancePlugin.applyCurrentStyle()
    }
    
    override func applicationWillEnterForeground(_ application: UIApplication) {
        print("applicationWillEnterForeground")
        SecurityBlurEffect.removeBlurEffect()
        ErosAppearancePlugin.applyCurrentStyle()
    }

    func addBlurEffect() {
        let BLURRED_IN_RECENT_TASK = "flutter.blurredInRecentTasks"

        let isBlurredInRecentTasks = UserDefaults.standard.bool(forKey: BLURRED_IN_RECENT_TASK)

        print("isBlurredInRecentTasks :", isBlurredInRecentTasks)
        if isBlurredInRecentTasks {
            SecurityBlurEffect.addBlurEffect()
        }
    }
}

#if !EROS_SIMULATOR_UI_TEST
private func registerPlugins(registry: FlutterPluginRegistry) {
    if (!registry.hasPlugin("FlutterDownloaderPlugin")) {
        FlutterDownloaderPlugin.register(with: registry.registrar(forPlugin: "FlutterDownloaderPlugin")!)
    }
}
#endif


@objc class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        window?.rootViewController?.loadViewIfNeeded()
        if let flutter = findFlutterViewController(from: window?.rootViewController) {
            registerSceneLifeCycle(with: flutter.engine)
        }
        super.scene(
            scene,
            willConnectTo: session,
            options: connectionOptions
        )
    }

    override func sceneDidEnterBackground(_ scene: UIScene) {
        super.sceneDidEnterBackground(scene)
        (UIApplication.shared.delegate as? AppDelegate)?.addBlurEffect()
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)
        SecurityBlurEffect.removeBlurEffect()
        ErosAppearancePlugin.applyCurrentStyle()
        #if EROS_SIMULATOR_UI_TEST
        if ProcessInfo.processInfo.arguments.contains("--eros-test-semantics") {
            findFlutterViewController(from: window?.rootViewController)?
                .engine.ensureSemanticsEnabled()
        }
        #endif
    }

    override func sceneWillEnterForeground(_ scene: UIScene) {
        super.sceneWillEnterForeground(scene)
        SecurityBlurEffect.removeBlurEffect()
        ErosAppearancePlugin.applyCurrentStyle()
    }

    private func findFlutterViewController(
        from controller: UIViewController?
    ) -> FlutterViewController? {
        guard let controller else { return nil }
        if let flutter = controller as? FlutterViewController {
            return flutter
        }
        if let presented = controller.presentedViewController,
           let flutter = findFlutterViewController(from: presented) {
            return flutter
        }
        if let navigation = controller as? UINavigationController,
           let flutter = findFlutterViewController(
               from: navigation.visibleViewController
           ) {
            return flutter
        }
        if let tab = controller as? UITabBarController,
           let flutter = findFlutterViewController(
               from: tab.selectedViewController
           ) {
            return flutter
        }
        for child in controller.children.reversed() {
            if let flutter = findFlutterViewController(from: child) {
                return flutter
            }
        }
        return nil
    }
}
