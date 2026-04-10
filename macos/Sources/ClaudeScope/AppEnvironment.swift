import Foundation

enum AppEnvironment {
    #if APP_STORE
    static let isAppStoreBuild = true
    #else
    static let isAppStoreBuild = false
    #endif
}

enum AppPaths {
    private static let fileManager = FileManager.default

    static var credentialsDirectoryURL: URL {
        if AppEnvironment.isAppStoreBuild,
           let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport.appendingPathComponent("ClaudeScope", isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/claude-scope", isDirectory: true)
    }

    static var legacyCredentialsDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/claude-usage-bar", isDirectory: true)
    }
}
