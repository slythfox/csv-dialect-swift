import Foundation

public typealias Field = String
public typealias Row = [Field]
public typealias Header = Row
public typealias Records = [Row]

/**
    Convenience model for working with CSV in-memory.

    - Note: Take advantage of data streaming capabilities when possible.
*/
public class Document: InputHandlerDelegate {

    public let dialect: Dialect?

    public var header: Header?
    public var records = Records()

    /**
        Initialize an empty document.
    */
    public init(dialect: Dialect? = nil) {
        self.dialect = dialect
    }

    /**
        Initialize a document populated with records and an optional header.
    */
    public convenience init(header: Header?, records: Records, dialect: Dialect? = nil) {
        self.init(dialect: dialect)
        self.header = header
        self.records = records
    }

    /**
        Initialize a document populated with records. Extract and set the header if denoted by the dialect.
    */
    public convenience init(allRows: Records, dialect: Dialect? = nil) {
        self.init(dialect: dialect)
        if let dialect = dialect, dialect.header {
            self.header = allRows.first ?? []
            self.records = Array(allRows.dropFirst(1))
        } else {
            self.records = allRows
        }
    }

    /**
        Initialize a document from a data representation.

        - Parameter data: Data which comprises of the entire document as a UTF-8 string.
        - Parameter dialect: Dialect from which to parse against.
    */
    public convenience init(data: Data, dialect: Dialect = Dialect()) throws {
        let parser = ImportParser(dialect: dialect)
        var allRows = try parser.import(data: data)
        if let row = try parser.flushRow() {
            allRows.append(row)
        }
        self.init(allRows: allRows, dialect: dialect)
    }

    /**
        Initialize a document from a CSV-formatted file.
    */
    public convenience init(fileHandle: FileHandle, dialect: Dialect = Dialect()) throws {
        self.init(dialect: dialect)
        let inputHandler = InputHandler(fileHandle: fileHandle, dialect: dialect)
        inputHandler.delegate = self
        try inputHandler.readToEndOfFile()
    }

    /**
        Export document to a UTF-8 encoded data representation.

        - Parameter dialect: Dialect to export against.
    */
    public func export(dialect: Dialect = Dialect()) throws -> Data {
        let parser = ExportParser(dialect: dialect)
        var data = Data()
        if let headerFields = self.header {
            data.append(try parser.export(records: [headerFields]))
        }
        data.append(try parser.export(records: self.records))
        return data
    }

    /**
        Export document to a CSV-formatted file.

        - Parameter dialect: Dialect to export against.
    */
    public func export(fileHandle: FileHandle, dialect: Dialect = Dialect()) throws -> Bool {
        let outputHandler = OutputHandler(fileHandle: fileHandle, dialect: dialect)
        try outputHandler.open(header: self.header)
        try outputHandler.append(records: self.records)
        try outputHandler.close()
        return true
    }

    /**
        - alreadyOpen: Indicates the document has already been initialized with data.
    */
    public enum InputError: Error {
    case alreadyOpen
    }

    // MARK: - InputHandlerDelegate

    /**
        - Note: Expects an empty document.
        - Throws: InputError
    */
    public func open(header: Header? = nil) throws {
        guard self.header == nil, self.records.count == 0 else {
            throw InputError.alreadyOpen
        }
        self.header = header
    }

    public func append(records: Records) throws {
        self.records.append(contentsOf: records)
    }

    public func close() throws {}

    public func reset() {}

}
