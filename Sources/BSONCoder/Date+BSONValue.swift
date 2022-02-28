import Foundation
import NIO

extension Date: BSONValue {
    internal static let extJSONTypeWrapperKeys: [String] = ["$date"]

    /// The range of datetimes that can be represented in BSON.
    private static let VALID_BSON_DATES: Range<Date> = Date(msSinceEpoch: Int64.min)..<Date(msSinceEpoch: Int64.max)

    /*
     * Initializes a `Date` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `Date`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value does not conform to the `Date` syntax.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        guard let value = try json.value.unwrapObject(withKey: "$date", keyPath: keyPath) else {
            return nil
        }
        switch value {
        case .object:
            // canonical extended JSON
            guard let int = try Int64(fromExtJSON: JSON(value), keyPath: keyPath) else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Expected \(value) to be canonical extended JSON representing a " +
                        "64-bit signed integer giving millisecs relative to the epoch, as a string"
                )
            }
            self = Date(msSinceEpoch: int)
        case let .string(s):
            // relaxed extended JSON
            // If fractional seconds are omitted in the input (no decimal point "."),
            // formatter should only account for seconds, otherwise formatter should take milliseconds into account
            let formatter = s.contains(".")
                ? ExtendedJSONDecoder.extJSONDateFormatterMilliseconds
                : ExtendedJSONDecoder.extJSONDateFormatterSeconds
            guard let date = formatter.date(from: s) else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Expected \(s) to be an ISO-8601 Internet Date/Time Format" +
                        " with maximum time precision of milliseconds as a string"
                )
            }
            self = date
        case let .number(ms):
            // legacy extended JSON
            guard let msInt64 = Int64(ms) else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Expected \(ms) to be valid Int64 representing milliseconds since epoch"
                )
            }
            self = Date(msSinceEpoch: msInt64)
        default:
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: "Expected \(value) to be canonical extended JSON representing a " +
                    "64-bit signed integer giving millisecs relative to the epoch, as a string OR " +
                    "relaxed extended JSON representing a ISO-8601 Internet Date/Time Format with " +
                    "maximum time precision of milliseconds as a string."
            )
        }
    }

    /// Converts this `BSONDate` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        // ExtendedJSON specifies 2 different ways to represent dates in
        // relaxed extended json depending on if the date is between 1970 and 9999
        // 1970 is 0 milliseconds since epoch, and 10,000 is 253,402,300,800,000.
        if self.msSinceEpoch >= 0 && self.msSinceEpoch < 253_402_300_800_000 {
            // Fractional seconds SHOULD have exactly 3 decimal places if the fractional part is non-zero.
            // Otherwise, fractional seconds SHOULD be omitted if zero.
            let formatter = self.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) == 0
                ? ExtendedJSONDecoder.extJSONDateFormatterSeconds
                : ExtendedJSONDecoder.extJSONDateFormatterMilliseconds
            let date = formatter.string(from: self)
            return ["$date": JSON(.string(date))]
        } else {
            return self.toCanonicalExtendedJSON()
        }
    }

    /// Converts this `BSONDate` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        ["$date": self.msSinceEpoch.toCanonicalExtendedJSON()]
    }

    internal static var bsonType: BSONType { .datetime }

    internal var bson: BSON { .datetime(self) }

    /// The number of milliseconds after the Unix epoch that this `Date` occurs.
    /// If the date is further in the future than Int64.max milliseconds from the epoch,
    /// Int64.max is returned to prevent a crash.
    internal var msSinceEpoch: Int64 {
        // to prevent the application from crashing, we simply clamp the date to the range representable
        // by an Int64 ms since epoch
        guard self > Self.VALID_BSON_DATES.lowerBound else {
            return Int64.min
        }
        guard self < Self.VALID_BSON_DATES.upperBound else {
            return Int64.max
        }

        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    /// Initializes a new `Date` representing the instance `msSinceEpoch` milliseconds
    /// since the Unix epoch.
    internal init(msSinceEpoch: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(msSinceEpoch) / 1000.0)
    }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let ms = buffer.readInteger(endianness: .little, as: Int64.self) else {
            throw BSONError.InternalError(message: "Unable to read UTC datetime (int64)")
        }
        return .datetime(Date(msSinceEpoch: ms))
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self.msSinceEpoch, endianness: .little, as: Int64.self)
    }

    internal func isValidBSONDate() -> Bool {
        Self.VALID_BSON_DATES.contains(self)
    }
}
