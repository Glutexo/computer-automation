struct SafariSavedTabGroupMutationContext {
    let summary: SafariTabGroupEnsureSummary
    let window: SafariWindowRecord

    static func prepare(
        ensureResult: SafariTabGroupEnsureOperationResult,
        openNewWindowForProfile: (String) throws -> SafariWindowRecord
    ) throws -> SafariSavedTabGroupMutationContext {
        let summary = ensureResult.summary
        let window = try ensureResult.createdWindow
            ?? openNewWindowForProfile(summary.tabGroup.profileName)

        return SafariSavedTabGroupMutationContext(summary: summary, window: window)
    }

    func rollback(
        deleteTabGroup: (Int) throws -> Void,
        closeWindow: (Int) throws -> Void
    ) throws {
        var cleanupError: Error?

        if summary.status == .created {
            do {
                try deleteTabGroup(summary.tabGroup.identifier)
            } catch {
                cleanupError = error
            }
        }

        do {
            try closeWindow(window.identifier)
        } catch {
            if cleanupError == nil {
                cleanupError = error
            }
        }

        if let cleanupError {
            throw cleanupError
        }
    }
}
