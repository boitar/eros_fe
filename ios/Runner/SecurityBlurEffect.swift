import UIKit

public class SecurityBlurEffect {
    private static let blurTag = 19999

    private static var appWindows: [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { $0.rootViewController != nil && $0.windowLevel == .normal }
    }

    class func addBlurEffect() {
        for window in appWindows where !window.isHidden {
            guard window.viewWithTag(blurTag) == nil else { continue }
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
            blur.tag = blurTag
            blur.alpha = 0.99
            blur.frame = window.bounds
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            window.addSubview(blur)
        }
    }

    class func removeBlurEffect() {
        for window in appWindows {
            window.subviews
                .filter { $0.tag == blurTag && $0 is UIVisualEffectView }
                .forEach { $0.removeFromSuperview() }
        }
    }
}
