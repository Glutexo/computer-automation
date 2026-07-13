public enum StableIdentifierMatching {
    public static func resolve<Candidate, Identifier: Equatable>(
        requestedIdentifier: Identifier?,
        from candidates: [Candidate],
        identifier: (Candidate) -> Identifier?,
        fallback: (Candidate) -> Bool
    ) -> Candidate? {
        guard let requestedIdentifier else {
            return candidates.first(where: fallback)
        }

        let identifiedCandidates = candidates.compactMap { candidate in
            identifier(candidate).map { (candidate, $0) }
        }

        if let match = identifiedCandidates.first(where: { $0.1 == requestedIdentifier }) {
            return match.0
        }

        guard identifiedCandidates.isEmpty else {
            return nil
        }

        return candidates.first(where: fallback)
    }

    public static func matches<Identifier: Equatable>(
        requestedIdentifier: Identifier,
        observedIdentifier: Identifier?,
        fallback: @autoclosure () -> Bool
    ) -> Bool {
        if let observedIdentifier {
            return observedIdentifier == requestedIdentifier
        }

        return fallback()
    }
}
