import AutomationFoundation
import ComputerAutomationKit
import Foundation
import MCP

public enum ComputerAutomationMCPMode: Sendable, Equatable {
    case readOnly
    case allCommands
}

public enum ComputerAutomationMCPToolError: Error, LocalizedError, Equatable, Sendable {
    case unknownTool(String)
    case mutationsDisabled(String)
    case unexpectedArgument(tool: String, argument: String)
    case missingArgument(tool: String, argument: String)
    case invalidArgument(tool: String, argument: String, expected: String)
    case invalidAlternative(tool: String, alternatives: [[String]])
    case invalidJSONOutput(tool: String)

    public var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            return "Unknown tool \(name)."
        case .mutationsDisabled(let name):
            return "Tool \(name) changes Safari state. Restart computer-automation-mcp with --allow-mutations to enable it."
        case .unexpectedArgument(let tool, let argument):
            return "Unexpected argument \(argument) for tool \(tool)."
        case .missingArgument(let tool, let argument):
            return "Missing required argument \(argument) for tool \(tool)."
        case .invalidArgument(let tool, let argument, let expected):
            return "Invalid argument \(argument) for tool \(tool); expected \(expected)."
        case .invalidAlternative(let tool, let alternatives):
            let choices = alternatives
                .map { $0.joined(separator: " + ") }
                .joined(separator: " or ")
            return "Tool \(tool) requires exactly one of: \(choices)."
        case .invalidJSONOutput(let tool):
            return "Tool \(tool) returned invalid JSON."
        }
    }
}

public struct ComputerAutomationMCPTool: Sendable, Equatable {
    public let moduleName: String
    public let command: CommandDescriptor
    public let arguments: [CommandArgumentDescriptor]
    public let usage: [CommandUsageComponent]?

    public var name: String {
        Self.toolName(moduleName: moduleName, commandName: command.name)
    }

    public var isReadOnly: Bool {
        command.isReadOnly
    }

    public init(moduleName: String, command: CommandDescriptor) {
        self.moduleName = moduleName
        self.command = command

        if moduleName == "safari", command.name == "execute-tab-javascript" {
            self.arguments = command.arguments.prefix(3).map { argument in
                CommandArgumentDescriptor(
                    name: argument.name,
                    kind: argument.kind,
                    valueType: argument.valueType,
                    isRequired: true,
                    valueName: argument.valueName,
                    isRepeating: argument.isRepeating,
                    completionSuggestions: argument.completionSuggestions
                )
            }
            self.usage = nil
        } else {
            self.arguments = command.arguments
            self.usage = command.usage
        }
    }

    public func mcpTool() -> Tool {
        let mutationNotice = isReadOnly
            ? ""
            : " Changes Safari state; available only when the server starts with --allow-mutations."

        return Tool(
            name: name,
            title: "\(moduleName) \(command.name)",
            description: command.abstract + mutationNotice,
            inputSchema: inputSchema,
            annotations: Tool.Annotations(
                title: command.abstract,
                readOnlyHint: isReadOnly,
                destructiveHint: isDestructive,
                idempotentHint: isReadOnly,
                openWorldHint: true
            )
        )
    }

    public func cliArguments(from values: [String: Value]) throws -> [String] {
        let argumentsByMCPName = Dictionary(uniqueKeysWithValues: arguments.map { ($0.mcpName, $0) })
        if let unexpected = values.keys.first(where: { argumentsByMCPName[$0] == nil }) {
            throw ComputerAutomationMCPToolError.unexpectedArgument(tool: name, argument: unexpected)
        }

        try validateRequiredArguments(values)

        var optionArguments: [String] = []
        var positionalArguments: [String] = []

        for argument in arguments {
            guard let value = values[argument.mcpName] else {
                continue
            }

            switch argument.kind {
            case .option:
                if argument.valueName == nil {
                    guard let enabled = value.boolValue else {
                        throw invalidValue(argument, expected: "a boolean")
                    }
                    if enabled {
                        optionArguments.append("--\(argument.name)")
                    }
                } else {
                    optionArguments.append("--\(argument.name)")
                    optionArguments.append(try scalarString(value, for: argument))
                }
            case .positional:
                if argument.isRepeating {
                    guard let items = value.arrayValue, !items.isEmpty else {
                        throw invalidValue(argument, expected: "a non-empty array of \(argument.valueType.schemaName) values")
                    }
                    positionalArguments.append(contentsOf: try items.map { try scalarString($0, for: argument) })
                } else {
                    positionalArguments.append(try scalarString(value, for: argument))
                }
            }
        }

        return optionArguments + positionalArguments
    }

    public static func toolName(moduleName: String, commandName: String) -> String {
        "\(normalizedName(moduleName))_\(normalizedName(commandName))"
    }

    private var inputSchema: Value {
        var properties: [String: Value] = [:]
        for argument in arguments {
            var property: [String: Value] = [
                "description": .string(argumentDescription(argument))
            ]

            if argument.kind == .option, argument.valueName == nil {
                property["type"] = "boolean"
            } else if argument.isRepeating {
                property["type"] = "array"
                property["items"] = .object(["type": .string(argument.valueType.schemaName)])
                property["minItems"] = 1
            } else {
                property["type"] = .string(argument.valueType.schemaName)
            }

            properties[argument.mcpName] = .object(property)
        }

        var schema: [String: Value] = [
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "type": "object",
            "properties": .object(properties),
            "additionalProperties": false
        ]

        let required = directlyRequiredArgumentNames
        if !required.isEmpty {
            schema["required"] = .array(required.sorted().map(Value.string))
        }

        let alternatives = requiredAlternatives
        if !alternatives.isEmpty {
            schema["allOf"] = .array(alternatives.map { alternatives in
                .object([
                    "oneOf": .array(alternatives.map { names in
                        .object(["required": .array(names.sorted().map(Value.string))])
                    })
                ])
            })
        }

        return .object(schema)
    }

    private var isDestructive: Bool {
        if isReadOnly {
            return false
        }

        switch command.operation {
        case .read, .update, .delete:
            return true
        case .create:
            return false
        }
    }

    private var directlyRequiredArgumentNames: [String] {
        guard let usage else {
            return arguments.filter(\.isRequired).map(\.mcpName)
        }

        return usage.compactMap { component in
            guard case .argument(let reference) = component else {
                return nil
            }
            guard let argument = arguments.first(where: { $0.name == reference.name }) else {
                return nil
            }
            return (reference.isRequired ?? argument.isRequired) ? argument.mcpName : nil
        }
    }

    private var requiredAlternatives: [[[String]]] {
        guard let usage else {
            return []
        }

        return usage.compactMap { component in
            guard case .alternatives(let alternatives) = component, alternatives.isRequired else {
                return nil
            }
            return alternatives.alternatives.map { alternative in
                argumentNames(in: alternative)
            }
        }
    }

    private func validateRequiredArguments(_ values: [String: Value]) throws {
        for required in directlyRequiredArgumentNames where !isPresent(required, in: values) {
            throw ComputerAutomationMCPToolError.missingArgument(tool: name, argument: required)
        }

        for alternatives in requiredAlternatives {
            let matching = alternatives.filter { names in
                names.allSatisfy { isPresent($0, in: values) }
            }
            guard matching.count == 1 else {
                throw ComputerAutomationMCPToolError.invalidAlternative(tool: name, alternatives: alternatives)
            }

            let selected = Set(matching[0])
            let nonSelected = Set(alternatives.flatMap { $0 }).subtracting(selected)
            if nonSelected.contains(where: { isPresent($0, in: values) }) {
                throw ComputerAutomationMCPToolError.invalidAlternative(tool: name, alternatives: alternatives)
            }
        }
    }

    private func isPresent(_ name: String, in values: [String: Value]) -> Bool {
        guard let value = values[name] else {
            return false
        }
        if value.boolValue == false {
            return false
        }
        if let items = value.arrayValue {
            return !items.isEmpty
        }
        return !value.isNull
    }

    private func argumentNames(in components: [CommandUsageComponent]) -> [String] {
        components.flatMap { component -> [String] in
            switch component {
            case .argument(let reference):
                return arguments
                    .first(where: { $0.name == reference.name })
                    .map { [$0.mcpName] } ?? []
            case .alternatives(let alternatives):
                return alternatives.alternatives.flatMap(argumentNames(in:))
            }
        }
    }

    private func scalarString(_ value: Value, for argument: CommandArgumentDescriptor) throws -> String {
        switch argument.valueType {
        case .string:
            guard let value = value.stringValue else {
                throw invalidValue(argument, expected: "a string")
            }
            return value
        case .integer:
            guard let value = value.intValue else {
                throw invalidValue(argument, expected: "an integer")
            }
            return String(value)
        }
    }

    private func invalidValue(
        _ argument: CommandArgumentDescriptor,
        expected: String
    ) -> ComputerAutomationMCPToolError {
        .invalidArgument(tool: name, argument: argument.mcpName, expected: expected)
    }

    private func argumentDescription(_ argument: CommandArgumentDescriptor) -> String {
        switch argument.kind {
        case .positional:
            return "Value for the \(argument.name) command argument."
        case .option where argument.valueName == nil:
            return "Whether to pass --\(argument.name)."
        case .option:
            return "Value for --\(argument.name)."
        }
    }

    private static func normalizedName(_ name: String) -> String {
        name.map { character in
            character.isLetter || character.isNumber ? character : "_"
        }.reduce(into: "", { $0.append($1) })
    }
}

public struct ComputerAutomationMCPToolCatalog: Sendable {
    public let mode: ComputerAutomationMCPMode
    public let allTools: [ComputerAutomationMCPTool]

    public var availableTools: [ComputerAutomationMCPTool] {
        switch mode {
        case .readOnly:
            return allTools.filter(\.isReadOnly)
        case .allCommands:
            return allTools
        }
    }

    public init(
        mode: ComputerAutomationMCPMode,
        modules: [ModuleDescriptor] = ComputerAutomationCLI.modules
    ) {
        self.mode = mode
        self.allTools = modules.flatMap { module in
            module.commands.map { ComputerAutomationMCPTool(moduleName: module.name, command: $0) }
        }
    }

    public func tool(named name: String) throws -> ComputerAutomationMCPTool {
        guard let tool = allTools.first(where: { $0.name == name }) else {
            throw ComputerAutomationMCPToolError.unknownTool(name)
        }
        guard mode == .allCommands || tool.isReadOnly else {
            throw ComputerAutomationMCPToolError.mutationsDisabled(name)
        }
        return tool
    }
}

public struct ComputerAutomationMCPToolDispatcher: Sendable {
    public typealias CommandExecutor = @Sendable ([String]) throws -> String

    public let catalog: ComputerAutomationMCPToolCatalog
    private let executeCommand: CommandExecutor

    public init(
        catalog: ComputerAutomationMCPToolCatalog,
        executeCommand: @escaping CommandExecutor = ComputerAutomationCLI.run
    ) {
        self.catalog = catalog
        self.executeCommand = executeCommand
    }

    public func call(name: String, arguments: [String: Value] = [:]) throws -> CallTool.Result {
        let tool: ComputerAutomationMCPTool
        do {
            tool = try catalog.tool(named: name)
        } catch ComputerAutomationMCPToolError.mutationsDisabled(let name) {
            return errorResult(ComputerAutomationMCPToolError.mutationsDisabled(name))
        }

        do {
            let cliArguments = try tool.cliArguments(from: arguments)
            let output = try executeCommand(["--json", tool.moduleName, tool.command.name] + cliArguments)
            guard
                let data = output.data(using: .utf8),
                let structuredOutput = try? JSONDecoder().decode(Value.self, from: data)
            else {
                throw ComputerAutomationMCPToolError.invalidJSONOutput(tool: tool.name)
            }

            return CallTool.Result(
                content: [.text(text: output, annotations: nil, _meta: nil)],
                structuredContent: Optional.some(structuredOutput),
                isError: false
            )
        } catch {
            return errorResult(error)
        }
    }

    private func errorResult(_ error: Error) -> CallTool.Result {
        CallTool.Result(
            content: [
                .text(
                    text: ComputerAutomationErrorRenderer.message(for: error),
                    annotations: nil,
                    _meta: nil
                )
            ],
            isError: true
        )
    }
}

private extension CommandArgumentDescriptor {
    var mcpName: String {
        let parts = name.split(separator: "-")
        guard let first = parts.first else {
            return name
        }
        return String(first) + parts.dropFirst().map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }.joined()
    }
}

private extension CommandArgumentDescriptor.ValueType {
    var schemaName: String {
        switch self {
        case .string:
            "string"
        case .integer:
            "integer"
        }
    }
}
