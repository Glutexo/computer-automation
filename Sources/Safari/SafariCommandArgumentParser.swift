struct SafariCommandArgumentOption: Equatable {
    enum ValueRequirement: Equatable {
        case flag
        case value(allowEmptyAfterOption: Bool = true, allowEmptyInEqualsForm: Bool = true)
    }

    let name: String
    let valueRequirement: ValueRequirement

    static func flag(_ name: String) -> SafariCommandArgumentOption {
        SafariCommandArgumentOption(name: name, valueRequirement: .flag)
    }

    static func value(
        _ name: String,
        allowEmptyAfterOption: Bool = true,
        allowEmptyInEqualsForm: Bool = true
    ) -> SafariCommandArgumentOption {
        SafariCommandArgumentOption(
            name: name,
            valueRequirement: .value(
                allowEmptyAfterOption: allowEmptyAfterOption,
                allowEmptyInEqualsForm: allowEmptyInEqualsForm
            )
        )
    }
}

enum SafariCommandArgumentToken: Equatable {
    case flag(String)
    case option(name: String, value: String)
    case positional(String)
}

struct SafariCommandArgumentScanner<Failure: Error> {
    private let arguments: [String]
    private let options: [SafariCommandArgumentOption]
    private let missingOptionValue: (String) -> Failure
    private let unknownOption: (String) -> Failure
    private var index = 0

    init(
        arguments: [String],
        options: [SafariCommandArgumentOption],
        missingOptionValue: @escaping (String) -> Failure,
        unknownOption: @escaping (String) -> Failure
    ) {
        self.arguments = arguments
        self.options = options
        self.missingOptionValue = missingOptionValue
        self.unknownOption = unknownOption
    }

    mutating func next() throws -> SafariCommandArgumentToken? {
        guard index < arguments.count else {
            return nil
        }

        let argument = arguments[index]
        if let option = options.first(where: { $0.name == argument }) {
            return try token(for: option)
        }

        if argument.hasPrefix("--") {
            if let option = options.first(where: { argument.hasPrefix($0.name + "=") }) {
                return try token(forEqualsArgument: argument, option: option)
            }

            throw unknownOption(argument)
        }

        index += 1
        return .positional(argument)
    }

    private mutating func token(for option: SafariCommandArgumentOption) throws -> SafariCommandArgumentToken {
        switch option.valueRequirement {
        case .flag:
            index += 1
            return .flag(option.name)
        case .value(let allowEmptyAfterOption, _):
            let valueIndex = index + 1
            guard
                valueIndex < arguments.count,
                !arguments[valueIndex].hasPrefix("--"),
                allowEmptyAfterOption || !arguments[valueIndex].isEmpty
            else {
                throw missingOptionValue(option.name)
            }

            index = valueIndex + 1
            return .option(name: option.name, value: arguments[valueIndex])
        }
    }

    private mutating func token(
        forEqualsArgument argument: String,
        option: SafariCommandArgumentOption
    ) throws -> SafariCommandArgumentToken {
        guard case .value(_, let allowEmptyInEqualsForm) = option.valueRequirement else {
            throw unknownOption(argument)
        }

        let valuePrefix = option.name + "="
        let value = String(argument.dropFirst(valuePrefix.count))
        guard allowEmptyInEqualsForm || !value.isEmpty else {
            throw missingOptionValue(option.name)
        }

        index += 1
        return .option(name: option.name, value: value)
    }
}

enum SafariArgumentValueParser {
    static func positiveInteger<Failure: Error>(
        _ rawValue: String,
        invalid: (String) -> Failure
    ) throws -> Int {
        guard let value = Int(rawValue), value > 0 else {
            throw invalid(rawValue)
        }
        return value
    }
}

struct SafariWindowIdentifierArguments: Equatable {
    let windowIdentifier: Int?
    let positionalArguments: [String]
}

struct SafariWindowAddressArguments: Equatable {
    let address: SafariWindowAddress
    let remainingArguments: [String]
}

enum SafariWindowAddressArgumentParser {
    static let windowIdentifierOption = "--window-id"
    static let windowIndexOption = "--window-index"

    static func parseWindowIdentifierArguments<ParserFailure: Error, InvalidIdentifierFailure: Error>(
        _ arguments: [String],
        allowEmptyIdentifierAfterOption: Bool,
        allowEmptyIdentifierInEqualsForm: Bool,
        missingOptionValue: @escaping (String) -> ParserFailure,
        unknownOption: @escaping (String) -> ParserFailure,
        invalidWindowIdentifier: (String) -> InvalidIdentifierFailure
    ) throws -> SafariWindowIdentifierArguments {
        var scanner = SafariCommandArgumentScanner(
            arguments: arguments,
            options: [
                .value(
                    windowIdentifierOption,
                    allowEmptyAfterOption: allowEmptyIdentifierAfterOption,
                    allowEmptyInEqualsForm: allowEmptyIdentifierInEqualsForm
                )
            ],
            missingOptionValue: missingOptionValue,
            unknownOption: unknownOption
        )

        var windowIdentifier: Int?
        var positionalArguments: [String] = []
        while let token = try scanner.next() {
            switch token {
            case .option(windowIdentifierOption, let rawValue):
                windowIdentifier = try SafariArgumentValueParser.positiveInteger(
                    rawValue,
                    invalid: invalidWindowIdentifier
                )
            case .positional(let argument):
                positionalArguments.append(argument)
            case .flag:
                break
            case .option:
                break
            }
        }

        return SafariWindowIdentifierArguments(
            windowIdentifier: windowIdentifier,
            positionalArguments: positionalArguments
        )
    }

    static func parseRequiredAddress<MissingFailure: Error, InvalidFailure: Error>(
        positionalArguments: [String],
        windowIdentifier: Int?,
        missingWindowIndex: () -> MissingFailure,
        invalidWindowIndex: (String) -> InvalidFailure
    ) throws -> SafariWindowAddressArguments {
        if let windowIdentifier {
            return SafariWindowAddressArguments(
                address: .identifier(windowIdentifier),
                remainingArguments: positionalArguments
            )
        }

        guard let rawWindowIndex = positionalArguments.first else {
            throw missingWindowIndex()
        }

        let windowIndex = try SafariArgumentValueParser.positiveInteger(
            rawWindowIndex,
            invalid: invalidWindowIndex
        )
        return SafariWindowAddressArguments(
            address: .index(windowIndex),
            remainingArguments: Array(positionalArguments.dropFirst())
        )
    }
}

struct SafariTabAddressArguments: Equatable {
    let address: SafariWindowAddress
    let tabIndex: Int
    let remainingArguments: [String]
}

enum SafariTabAddressArgumentParser {
    static func parseRequiredAddress<
        MissingWindowFailure: Error,
        MissingTabFailure: Error,
        InvalidWindowFailure: Error,
        InvalidTabFailure: Error
    >(
        positionalArguments: [String],
        windowIdentifier: Int?,
        missingWindowIndex: () -> MissingWindowFailure,
        missingTabAddress: () -> MissingTabFailure,
        invalidWindowIndex: (String) -> InvalidWindowFailure,
        invalidTabAddress: (String, String) -> InvalidTabFailure
    ) throws -> SafariTabAddressArguments {
        if let windowIdentifier {
            guard let rawTabIndex = positionalArguments.first else {
                throw missingTabAddress()
            }

            let tabIndex = try SafariArgumentValueParser.positiveInteger(rawTabIndex) { rawValue in
                invalidTabAddress(String(windowIdentifier), rawValue)
            }
            return SafariTabAddressArguments(
                address: .identifier(windowIdentifier),
                tabIndex: tabIndex,
                remainingArguments: Array(positionalArguments.dropFirst())
            )
        }

        guard let rawWindowIndex = positionalArguments.first else {
            throw missingWindowIndex()
        }
        guard positionalArguments.count >= 2 else {
            throw missingTabAddress()
        }

        let windowIndex = try SafariArgumentValueParser.positiveInteger(
            rawWindowIndex,
            invalid: invalidWindowIndex
        )
        let rawTabIndex = positionalArguments[1]
        let tabIndex = try SafariArgumentValueParser.positiveInteger(rawTabIndex) { rawValue in
            invalidTabAddress(rawWindowIndex, rawValue)
        }

        return SafariTabAddressArguments(
            address: .index(windowIndex),
            tabIndex: tabIndex,
            remainingArguments: Array(positionalArguments.dropFirst(2))
        )
    }
}

struct SafariTabListAddressedURLsArguments: Equatable {
    enum Context: Equatable {
        case window(SafariWindowAddress)
        case tabGroup(profileName: String, name: String)
    }

    let context: Context
    let urls: [String]

    static func parse(_ arguments: [String]) throws -> SafariTabListAddressedURLsArguments {
        var scanner = SafariCommandArgumentScanner(
            arguments: arguments,
            options: [
                .value(SafariWindowAddressArgumentParser.windowIndexOption, allowEmptyInEqualsForm: false),
                .value(SafariWindowAddressArgumentParser.windowIdentifierOption, allowEmptyInEqualsForm: false),
                .value("--tab-group-profile"),
                .value("--tab-group-name")
            ],
            missingOptionValue: SafariTabListCommandError.missingOptionValue,
            unknownOption: SafariTabListCommandError.unknownOption
        )

        var windowIndex: Int?
        var windowIdentifier: Int?
        var tabGroupProfile: String?
        var tabGroupName: String?
        var urls: [String] = []

        while let token = try scanner.next() {
            switch token {
            case .option(SafariWindowAddressArgumentParser.windowIndexOption, let rawValue):
                windowIndex = try SafariArgumentValueParser.positiveInteger(
                    rawValue,
                    invalid: SafariTabCommandError.invalidWindowIndex
                )
            case .option(SafariWindowAddressArgumentParser.windowIdentifierOption, let rawValue):
                windowIdentifier = try SafariArgumentValueParser.positiveInteger(
                    rawValue,
                    invalid: SafariTabCommandError.invalidWindowIdentifier
                )
            case .option("--tab-group-profile", let value):
                tabGroupProfile = value
            case .option("--tab-group-name", let value):
                tabGroupName = value
            case .positional(let argument):
                urls.append(argument)
            case .flag:
                break
            case .option:
                break
            }
        }

        guard !urls.isEmpty else {
            throw SafariTabListCommandError.missingURL
        }

        if windowIndex != nil && windowIdentifier != nil {
            throw SafariTabListCommandError.multipleContexts
        }

        if (windowIndex != nil || windowIdentifier != nil) && (tabGroupProfile != nil || tabGroupName != nil) {
            throw SafariTabListCommandError.multipleContexts
        }

        if let windowIndex {
            return SafariTabListAddressedURLsArguments(context: .window(.index(windowIndex)), urls: urls)
        }

        if let windowIdentifier {
            return SafariTabListAddressedURLsArguments(context: .window(.identifier(windowIdentifier)), urls: urls)
        }

        guard let tabGroupProfile else {
            throw tabGroupName == nil ? SafariTabListCommandError.missingContext : SafariTabListCommandError.missingTabGroupProfile
        }
        guard !tabGroupProfile.isEmpty else {
            throw SafariTabListCommandError.emptyTabGroupProfile
        }

        guard let tabGroupName else {
            throw SafariTabListCommandError.missingTabGroupName
        }
        guard !tabGroupName.isEmpty else {
            throw SafariTabListCommandError.emptyTabGroupName
        }

        return SafariTabListAddressedURLsArguments(
            context: .tabGroup(profileName: tabGroupProfile, name: tabGroupName),
            urls: urls
        )
    }
}
