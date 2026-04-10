import Foundation

#if APP_STORE
@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var isConfigured = false
    @Published private(set) var lastError: String?

    init(bundle: Bundle = .main) {}

    func checkForUpdates() {
        lastError = localizedString(
            "error.updater_not_configured",
            fallback: "Updater is not configured for this build"
        )
    }
}
#else
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var isConfigured: Bool
    @Published private(set) var lastError: String?

    private let updaterController: SPUStandardUpdaterController
    private var canCheckObservation: NSKeyValueObservation?

    init(bundle: Bundle = .main) {
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        self.isConfigured = !(feedURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            && !(publicKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        canCheckObservation = updaterController.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] updater, _ in
            let canCheck = updater.canCheckForUpdates
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = canCheck
            }
        }

        guard isConfigured else { return }

        updaterController.startUpdater()
    }

    func checkForUpdates() {
        guard isConfigured else {
            lastError = localizedString(
                "error.updater_not_configured",
                fallback: "Updater is not configured for this build"
            )
            return
        }

        updaterController.checkForUpdates(nil)
    }
}
#endif
