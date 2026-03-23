import SwiftUI
import UIKit

// MARK: - Navigation Swipe-Back Restorer
// UIKit disables interactivePopGestureRecognizer when the navigation bar is hidden.
// This representable re-enables it with a delegate that permits the pop whenever
// there is a view controller to go back to.

struct SwipeBackEnabler: UIViewRepresentable {
    func makeUIView(context: Context) -> EnablerView { EnablerView() }
    func updateUIView(_ uiView: EnablerView, context: Context) {}

    final class EnablerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.restore() }
        }

        private func restore() {
            var responder: UIResponder? = self
            while let next = responder?.next {
                if let nav = next as? UINavigationController {
                    nav.interactivePopGestureRecognizer?.isEnabled = true
                    nav.interactivePopGestureRecognizer?.delegate = PopGestureDelegate.shared
                    return
                }
                responder = next
            }
        }
    }
}

// Singleton delegate — lives for the app's lifetime so the weak delegate reference stays valid.
private final class PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = PopGestureDelegate()

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        var responder: UIResponder? = gestureRecognizer.view
        while let next = responder?.next {
            if let nav = next as? UINavigationController {
                return nav.viewControllers.count > 1
            }
            responder = next
        }
        return false
    }
}

extension View {
    /// Re-enables the iOS interactive swipe-back gesture on views where
    /// `.toolbar(.hidden, for: .navigationBar)` has disabled it.
    func enableNavigationBackSwipe() -> some View {
        background(SwipeBackEnabler().frame(width: 0, height: 0))
    }
}
