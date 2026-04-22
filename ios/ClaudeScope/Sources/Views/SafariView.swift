import SwiftUI
import SafariServices

/// Wraps `SFSafariViewController` for SwiftUI `.sheet` presentation.
/// Used for the OAuth authorize page so the browser stays in-app
/// (Apple Guideline 4 requires this — external Safari is rejected).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(red: 0.18, green: 0.55, blue: 0.50, alpha: 1) // Theme.teal
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
