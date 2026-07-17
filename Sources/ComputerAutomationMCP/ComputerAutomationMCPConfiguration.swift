import Foundation

public struct ComputerAutomationMCPConfiguration: Sendable, Equatable {
    public let mode: ComputerAutomationMCPMode

    public init(mode: ComputerAutomationMCPMode) {
        self.mode = mode
    }

    public static func parse(arguments: [String]) throws -> ComputerAutomationMCPConfiguration {
        var mode = ComputerAutomationMCPMode.readOnly

        for argument in arguments {
            switch argument {
            case "--allow-mutations":
                mode = .allCommands
            default:
                throw ComputerAutomationMCPConfigurationError.unknownArgument(argument)
            }
        }

        return ComputerAutomationMCPConfiguration(mode: mode)
    }
}

public enum ComputerAutomationMCPConfigurationError: Error, LocalizedError, Equatable {
    case unknownArgument(String)

    public var errorDescription: String? {
        switch self {
        case .unknownArgument(let argument):
            "Unknown MCP server argument \(argument)."
        }
    }
}
