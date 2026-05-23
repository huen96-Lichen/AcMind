import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

internal enum SQLiteStoredValue: Sendable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)

    var stringValue: String? {
        switch self {
        case .null:
            return nil
        case .integer(let value):
            return String(value)
        case .real(let value):
            return String(value)
        case .text(let value):
            return value
        case .blob(let value):
            return String(data: value, encoding: .utf8)
        }
    }

    var intValue: Int? {
        switch self {
        case .null:
            return nil
        case .integer(let value):
            return Int(value)
        case .real(let value):
            return Int(value)
        case .text(let value):
            return Int(value)
        case .blob:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .null:
            return nil
        case .integer(let value):
            return Double(value)
        case .real(let value):
            return value
        case .text(let value):
            return Double(value)
        case .blob:
            return nil
        }
    }

    var boolValue: Bool? {
        guard let value = intValue else { return nil }
        return value != 0
    }

    var dataValue: Data? {
        switch self {
        case .blob(let value):
            return value
        case .text(let value):
            return value.data(using: .utf8)
        default:
            return nil
        }
    }
}

public struct SQLiteRow: Sendable {
    private let values: [String: SQLiteStoredValue]

    init(values: [String: SQLiteStoredValue]) {
        self.values = values
    }

    subscript(_ key: String) -> SQLiteStoredValue? {
        values[key]
    }

    func string(_ key: String) -> String? {
        values[key]?.stringValue
    }

    func int(_ key: String) -> Int? {
        values[key]?.intValue
    }

    func double(_ key: String) -> Double? {
        values[key]?.doubleValue
    }

    func bool(_ key: String) -> Bool? {
        values[key]?.boolValue
    }

    func data(_ key: String) -> Data? {
        values[key]?.dataValue
    }
}

internal final class SQLiteConnection {
    private var handle: OpaquePointer?

    init(path: String, readOnly: Bool = false) throws {
        var db: OpaquePointer?
        let flags = readOnly
            ? (SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
            : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX)

        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK, let opened = db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite open error"
            throw SQLiteError.openFailed(message)
        }

        handle = opened
        sqlite3_busy_timeout(opened, 5_000)

        if !readOnly {
            try execute("PRAGMA foreign_keys = ON")
            _ = try query("PRAGMA journal_mode = WAL") { _ in () }
            try execute("PRAGMA synchronous = NORMAL")
        }
    }

    deinit {
        if let handle {
            sqlite3_close_v2(handle)
        }
    }

    var changesCount: Int {
        guard let handle else { return 0 }
        return Int(sqlite3_changes(handle))
    }

    func execute(_ sql: String, arguments: [Any?] = []) throws {
        let statement = try prepare(sql, arguments: arguments)
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executionFailed(message())
        }
    }

    func query<T>(_ sql: String, arguments: [Any?] = [], mapper: (SQLiteRow) throws -> T) throws -> [T] {
        let statement = try prepare(sql, arguments: arguments)
        defer { sqlite3_finalize(statement) }

        var results: [T] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_ROW {
                results.append(try mapper(makeRow(from: statement)))
            } else if status == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.executionFailed(message())
            }
        }
        return results
    }

    func queryOne<T>(_ sql: String, arguments: [Any?] = [], mapper: (SQLiteRow) throws -> T) throws -> T? {
        try query(sql, arguments: arguments, mapper: mapper).first
    }

    func tableExists(_ table: String) throws -> Bool {
        let rows = try query(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
            arguments: [table]
        ) { row in row.string("name") ?? "" }
        return !rows.isEmpty
    }

    func columnExists(_ table: String, column: String) throws -> Bool {
        let rows = try query("PRAGMA table_info(\(table))") { row in row.string("name") ?? "" }
        return rows.contains(column)
    }

    private func prepare(_ sql: String, arguments: [Any?]) throws -> OpaquePointer? {
        guard let handle else { throw SQLiteError.notOpen }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let prepared = statement else {
            throw SQLiteError.prepareFailed(message())
        }

        try bind(arguments: arguments, to: prepared)
        return prepared
    }

    private func bind(arguments: [Any?], to statement: OpaquePointer) throws {
        for (index, argument) in arguments.enumerated() {
            let position = Int32(index + 1)
            let code: Int32

            switch argument {
            case nil, is NSNull:
                code = sqlite3_bind_null(statement, position)
            case let value as String:
                code = value.withCString { sqlite3_bind_text(statement, position, $0, -1, SQLITE_TRANSIENT) }
            case let value as NSString:
                let text = value as String
                code = text.withCString { sqlite3_bind_text(statement, position, $0, -1, SQLITE_TRANSIENT) }
            case let value as Int:
                code = sqlite3_bind_int64(statement, position, sqlite3_int64(value))
            case let value as Int64:
                code = sqlite3_bind_int64(statement, position, value)
            case let value as Int32:
                code = sqlite3_bind_int64(statement, position, sqlite3_int64(value))
            case let value as UInt:
                code = sqlite3_bind_int64(statement, position, sqlite3_int64(value))
            case let value as Double:
                code = sqlite3_bind_double(statement, position, value)
            case let value as Float:
                code = sqlite3_bind_double(statement, position, Double(value))
            case let value as Bool:
                code = sqlite3_bind_int(statement, position, value ? 1 : 0)
            case let value as Date:
                code = sqlite3_bind_int64(statement, position, sqlite3_int64(value.timeIntervalSince1970))
            case let value as Data:
                code = value.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, position, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
                }
            case let value as URL:
                code = value.path.withCString { sqlite3_bind_text(statement, position, $0, -1, SQLITE_TRANSIENT) }
            case let value as UUID:
                code = value.uuidString.withCString { sqlite3_bind_text(statement, position, $0, -1, SQLITE_TRANSIENT) }
            default:
                let text = String(describing: argument ?? "")
                code = text.withCString { sqlite3_bind_text(statement, position, $0, -1, SQLITE_TRANSIENT) }
            }

            guard code == SQLITE_OK else {
                throw SQLiteError.bindFailed(message())
            }
        }
    }

    private func makeRow(from statement: OpaquePointer?) -> SQLiteRow {
        guard let statement else { return SQLiteRow(values: [:]) }

        let columnCount = sqlite3_column_count(statement)
        var values: [String: SQLiteStoredValue] = [:]
        values.reserveCapacity(Int(columnCount))

        for index in 0..<columnCount {
            guard let namePointer = sqlite3_column_name(statement, index) else { continue }
            let name = String(cString: namePointer)
            let type = sqlite3_column_type(statement, index)

            switch type {
            case SQLITE_INTEGER:
                values[name] = .integer(sqlite3_column_int64(statement, index))
            case SQLITE_FLOAT:
                values[name] = .real(sqlite3_column_double(statement, index))
            case SQLITE_BLOB:
                if let blob = sqlite3_column_blob(statement, index) {
                    let size = Int(sqlite3_column_bytes(statement, index))
                    values[name] = .blob(Data(bytes: blob, count: size))
                } else {
                    values[name] = .blob(Data())
                }
            case SQLITE_TEXT:
                if let textPointer = sqlite3_column_text(statement, index) {
                    values[name] = .text(String(cString: textPointer))
                } else {
                    values[name] = .null
                }
            default:
                values[name] = .null
            }
        }

        return SQLiteRow(values: values)
    }

    private func message() -> String {
        guard let handle else { return "SQLite error" }
        return String(cString: sqlite3_errmsg(handle))
    }
}

internal enum SQLiteError: Error, LocalizedError {
    case notOpen
    case openFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notOpen:
            return "SQLite connection not open"
        case .openFailed(let message):
            return "SQLite open failed: \(message)"
        case .prepareFailed(let message):
            return "SQLite prepare failed: \(message)"
        case .bindFailed(let message):
            return "SQLite bind failed: \(message)"
        case .executionFailed(let message):
            return "SQLite execution failed: \(message)"
        }
    }
}
