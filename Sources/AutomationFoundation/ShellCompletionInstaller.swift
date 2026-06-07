import Foundation

public struct ShellCompletionInstallResult: Equatable {
    public let filePath: String
    public let directoryPath: String
    public let requiresFpathUpdate: Bool

    public init(filePath: String, directoryPath: String, requiresFpathUpdate: Bool) {
        self.filePath = filePath
        self.directoryPath = directoryPath
        self.requiresFpathUpdate = requiresFpathUpdate
    }
}

public enum ShellCompletionInstaller {
    public static func installZsh(
        executableName: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws -> ShellCompletionInstallResult {
        guard let homeDirectory = environment["HOME"], !homeDirectory.isEmpty else {
            throw CLIError.missingHomeDirectory
        }

        let directoryPath = resolveZshDirectory(homeDirectory: homeDirectory, fileManager: fileManager)
        let filePath = "\(directoryPath)/_\(executableName)"
        let script = ShellCompletionScriptRenderer.zsh(executableName: executableName)

        try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true)
        try script.write(toFile: filePath, atomically: true, encoding: .utf8)

        let currentFpath = parseFpath(environment["FPATH"])
        let requiresFpathUpdate = !currentFpath.contains(directoryPath)

        return ShellCompletionInstallResult(
            filePath: filePath,
            directoryPath: directoryPath,
            requiresFpathUpdate: requiresFpathUpdate
        )
    }

    static func resolveZshDirectory(
        homeDirectory: String,
        fileManager: FileManager = .default
    ) -> String {
        let candidates = [
            "\(homeDirectory)/.zfunc",
            "\(homeDirectory)/.zsh/completions"
        ]

        for candidate in candidates where fileManager.fileExists(atPath: candidate) {
            return candidate
        }

        return "\(homeDirectory)/.zsh/completions"
    }

    static func parseFpath(_ rawValue: String?) -> [String] {
        guard let rawValue, !rawValue.isEmpty else {
            return []
        }

        return rawValue
            .split(separator: ":")
            .map(String.init)
    }
}
