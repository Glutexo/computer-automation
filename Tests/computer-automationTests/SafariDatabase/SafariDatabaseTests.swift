import Testing
import Foundation
import ApplicationServices
import SQLite3
@testable import AutomationFoundation
@testable import SafariAppleScript
@testable import SafariDatabase
@testable import Safari
@testable import SafariUserInterface
@testable import ComputerAutomationKit

@Test func safariDatabaseOpenErrorsExplainFullDiskAccessRequirement() async throws {
    let error = SafariTabGroupCommandError.databaseOpenFailed(path: "/protected/SafariTabs.db")

    #expect(error.localizedDescription.contains("Grant Full Disk Access"))
    #expect(error.localizedDescription.contains("/protected/SafariTabs.db"))
}

@Test func safariWindowLoadsProfilesByWindowIdentifier() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let databasePath = temporaryDirectory.appendingPathComponent("SafariTabs.db").path
    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        subtype INTEGER
    );
    CREATE TABLE windows (
        id INTEGER PRIMARY KEY,
        active_tab_group_id INTEGER,
        active_profile_id INTEGER,
        date_closed REAL,
        private_tab_group_id INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, subtype) VALUES
        (5, 0, 1, 'Glutexo', 2),
        (288, 0, 1, 'Twisto', 2);
    INSERT INTO windows (id, active_tab_group_id, active_profile_id, date_closed, private_tab_group_id) VALUES
        (1, 100, 5, NULL, 101),
        (2, 200, 288, NULL, 201),
        (3, 300, 288, 1.0, 301);
    """

    let database = try #require(openDatabase(at: databasePath))
    defer { sqlite3_close(database) }
    #expect(sqlite3_exec(database, setupSQL, nil, nil, nil) == SQLITE_OK)

    let profiles = try SafariDatabaseWindow.loadProfilesByWindowIdentifier(databasePath: databasePath)
    #expect(
        profiles ==
        [
            1: "Glutexo",
            2: "Twisto"
        ]
    )
}

@Test func safariWindowLoadProfilesRejectsMissingDatabase() async throws {
    let missingPath = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("Missing.db")
        .path

    #expect(throws: SafariDatabaseError.openFailed(path: missingPath)) {
        try SafariDatabaseWindow.loadProfilesByWindowIdentifier(databasePath: missingPath)
    }
}

@Test func safariWindowLoadProfilesRejectsMissingSchema() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    #expect(throws: SafariDatabaseError.queryPreparationFailed(modelName: "window")) {
        try SafariDatabaseWindow.loadProfilesByWindowIdentifier(databasePath: databasePath)
    }
}

@Test func safariWindowLoadProfilesMapsMissingBookmarksToEmptyString() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        subtype INTEGER
    );
    CREATE TABLE windows (
        id INTEGER PRIMARY KEY,
        active_tab_group_id INTEGER,
        active_profile_id INTEGER,
        date_closed REAL,
        private_tab_group_id INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, subtype) VALUES
        (5, 0, 1, 'Glutexo', 2),
        (6, 0, 1, NULL, 2);
    INSERT INTO windows (id, active_tab_group_id, active_profile_id, date_closed, private_tab_group_id) VALUES
        (1, 100, 5, NULL, 101),
        (2, 200, 6, NULL, 201),
        (3, 300, 999, NULL, 301),
        (4, 400, 5, 1.0, 401);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseWindow.loadProfilesByWindowIdentifier(databasePath: databasePath) ==
        [
            1: "Glutexo",
            2: "",
            3: ""
        ]
    )
}

@Test func safariWindowLoadProfilesFallsBackToSelectedTabGroupParentProfile() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        subtype INTEGER
    );
    CREATE TABLE windows (
        id INTEGER PRIMARY KEY,
        active_tab_group_id INTEGER,
        active_profile_id INTEGER,
        date_closed REAL,
        private_tab_group_id INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, subtype) VALUES
        (288, 0, 1, 'Twisto', 2),
        (1000, 288, 1, 'Focus', 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', 1);
    INSERT INTO windows (id, active_tab_group_id, active_profile_id, date_closed, private_tab_group_id) VALUES
        (1, 1000, NULL, NULL, NULL);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseWindow.loadProfilesByWindowIdentifier(databasePath: databasePath) ==
        [
            1: "Twisto"
        ]
    )
}

@Test func safariWindowLoadsPrivateStateByWindowIdentifier() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        subtype INTEGER
    );
    CREATE TABLE windows (
        id INTEGER PRIMARY KEY,
        active_tab_group_id INTEGER,
        active_profile_id INTEGER,
        date_closed REAL,
        private_tab_group_id INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, subtype) VALUES
        (5, 0, 1, 'Glutexo', 2),
        (6, 0, 1, 'Twisto', 2),
        (1000, 6, 1, 'Focus', 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', 1);
    INSERT INTO windows (id, active_tab_group_id, active_profile_id, date_closed, private_tab_group_id) VALUES
        (1, 100, 5, NULL, 101),
        (2, 202, 6, NULL, 202),
        (3, 1000, 6, NULL, NULL),
        (4, 404, 5, 1.0, 404);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseWindow.loadStateByWindowIdentifier(databasePath: databasePath) ==
        [
            1: SafariDatabaseWindowStateRecord(profileName: "Glutexo", selectedTabGroupIdentifier: nil, tabGroupName: nil, isPrivate: false),
            2: SafariDatabaseWindowStateRecord(profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, isPrivate: true),
            3: SafariDatabaseWindowStateRecord(profileName: "Twisto", selectedTabGroupIdentifier: 1000, tabGroupName: "Focus", isPrivate: false)
        ]
    )
}

@Test func safariTabGroupListsSavedGroupsOnly() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        external_uuid TEXT,
        subtype INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, external_uuid, subtype) VALUES
        (5, 0, 1, 'Glutexo', 'profile-a', 2),
        (288, 0, 1, 'Twisto', 'profile-b', 2),
        (1000, 288, 1, 'Focus', 'group-1', 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', 'scope-1', 1),
        (1002, 1000, 0, 'OpenAI', 'page-1', 0),
        (1008, 0, 1, 'Root Group', 'root-group', 0),
        (1009, 1008, 1, 'TopScopedBookmarkList', 'root-scope', 1),
        (1003, NULL, 1, 'Local', 'local-1', 0),
        (1004, NULL, 1, 'Private', 'private-1', 0),
        (1005, 288, 1, 'No Scope Group', 'group-2', 0),
        (1006, 999, 1, 'Wrong Parent Group', 'group-3', 0),
        (1007, 1006, 1, 'TopScopedBookmarkList', 'scope-2', 1);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseTabGroup.list(databasePath: databasePath) ==
        [
            SafariDatabaseTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
            SafariDatabaseTabGroupRecord(identifier: 1008, profileName: "", name: "Root Group")
        ]
    )
}

@Test func safariTabGroupListNormalizesRootGroupsToDefaultProfileName() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        external_uuid TEXT,
        subtype INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, external_uuid, subtype) VALUES
        (5, 0, 1, 'Glutexo', 'profile-a', 2),
        (288, 0, 1, 'Twisto', 'profile-b', 2),
        (1000, 288, 1, 'Focus', 'group-1', 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', 'scope-1', 1),
        (1002, 1000, 0, 'OpenAI', 'page-1', 0),
        (1008, 0, 1, 'Root Group', 'root-group', 0),
        (1009, 1008, 1, 'TopScopedBookmarkList', 'root-scope', 1);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariTabGroup.list(databasePath: databasePath) ==
        [
            SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
            SafariTabGroupRecord(identifier: 1008, profileName: "Glutexo", name: "Root Group")
        ]
    )
}

@Test func safariTabGroupRejectsMissingDatabaseOrSchema() async throws {
    let missingPath = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("Missing.db")
        .path

    #expect(throws: SafariDatabaseError.openFailed(path: missingPath)) {
        try SafariDatabaseTabGroup.list(databasePath: missingPath)
    }

    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    #expect(throws: SafariDatabaseError.queryPreparationFailed(modelName: "tab-group")) {
        try SafariDatabaseTabGroup.list(databasePath: databasePath)
    }

    #expect(throws: SafariDatabaseError.queryPreparationFailed(modelName: "tab-group")) {
        try SafariDatabaseTabGroup.listTabs(tabGroupIdentifier: 1000, databasePath: databasePath)
    }
}

@Test func safariTabGroupListsTabsInBookmarkOrder() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        url TEXT,
        order_index INTEGER NOT NULL,
        subtype INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, url, order_index, subtype) VALUES
        (5, 0, 1, 'Glutexo', NULL, 0, 2),
        (1000, 5, 1, 'Focus', NULL, 0, 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', NULL, 0, 1),
        (1002, 1000, 0, 'OpenAI', 'https://openai.com', 2, 0),
        (1003, 1000, 0, 'Example', 'https://example.com', 1, 0),
        (1004, 1000, 0, 'Empty URL', NULL, 3, 0),
        (2000, NULL, 1, 'Local', NULL, 0, 0),
        (2001, 2000, 1, 'TopScopedBookmarkList', NULL, 0, 1),
        (2002, 2000, 0, 'Ignored Local Tab', 'https://ignored.local', 1, 0);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseTabGroup.listTabs(tabGroupIdentifier: 1000, databasePath: databasePath) ==
        [
            SafariDatabaseTabGroupTabRecord(tabGroupIdentifier: 1000, index: 1, url: "https://example.com"),
            SafariDatabaseTabGroupTabRecord(tabGroupIdentifier: 1000, index: 2, url: "https://openai.com"),
            SafariDatabaseTabGroupTabRecord(tabGroupIdentifier: 1000, index: 3, url: "")
        ]
    )
}

@Test func safariTabGroupListsTabsForRootSavedGroup() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        url TEXT,
        order_index INTEGER NOT NULL,
        subtype INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, url, order_index, subtype) VALUES
        (1000, 0, 1, 'Root Group', NULL, 0, 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', NULL, 0, 1),
        (1002, 1000, 0, 'Example', 'https://example.com', 1, 0);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseTabGroup.listTabs(tabGroupIdentifier: 1000, databasePath: databasePath) ==
        [
            SafariDatabaseTabGroupTabRecord(tabGroupIdentifier: 1000, index: 1, url: "https://example.com")
        ]
    )
}

@Test func safariProfileListsSubtypeTwoRootBookmarks() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let databasePath = temporaryDirectory.appendingPathComponent("SafariTabs.db").path
    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        external_uuid TEXT,
        subtype INTEGER
    );
    INSERT INTO bookmarks (parent, type, title, external_uuid, subtype) VALUES
        (0, 1, 'Glutexo', 'DefaultProfile', 2),
        (0, 1, 'Twisto', '33782F17-8AAD-41EA-BCB5-71A1A8348C55', 2),
        (0, 1, 'Bookmarks Folder', 'not-a-profile', 0),
        (15, 1, 'Nested Profile-Like Folder', 'nested', 2);
    """

    let database = try #require(openDatabase(at: databasePath))
    defer { sqlite3_close(database) }

    let createResult = sqlite3_exec(database, setupSQL, nil, nil, nil)
    #expect(createResult == SQLITE_OK)

    let profiles = try SafariDatabaseProfile.list(databasePath: databasePath)
    #expect(
        profiles ==
        [
            SafariDatabaseProfileRecord(name: "Glutexo", identifier: "DefaultProfile"),
            SafariDatabaseProfileRecord(name: "Twisto", identifier: "33782F17-8AAD-41EA-BCB5-71A1A8348C55")
        ]
    )
}

@Test func safariProfileDatabasePathUsesProvidedHomeDirectory() async throws {
    #expect(
        SafariTabsDatabase.databasePath(homeDirectory: "/tmp/example-home") ==
        "/tmp/example-home/Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db"
    )
}

@Test func safariProfileListAvailableProfilesRejectsMissingDatabase() async throws {
    let missingPath = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("Missing.db")
        .path

    #expect(throws: SafariDatabaseError.openFailed(path: missingPath)) {
        try SafariDatabaseProfile.list(databasePath: missingPath)
    }
}

@Test func safariProfileListAvailableProfilesRejectsMissingSchema() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    #expect(throws: SafariDatabaseError.queryPreparationFailed(modelName: "profile")) {
        try SafariDatabaseProfile.list(databasePath: databasePath)
    }
}

@Test func safariProfileListAvailableProfilesSkipsRowsWithNullFieldsAndPreservesOrder() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        external_uuid TEXT,
        subtype INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, external_uuid, subtype) VALUES
        (10, 0, 1, 'Beta', 'beta-id', 2),
        (11, 0, 1, NULL, 'missing-title', 2),
        (12, 0, 1, 'Gamma', NULL, 2),
        (13, 0, 1, 'Alpha', 'alpha-id', 2),
        (14, 1, 1, 'Nested', 'nested-id', 2);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseProfile.list(databasePath: databasePath) ==
        [
            SafariDatabaseProfileRecord(name: "Beta", identifier: "beta-id"),
            SafariDatabaseProfileRecord(name: "Alpha", identifier: "alpha-id")
        ]
    )
}
