import Foundation
import NIO

private extension UInt64 {
    var upper32bits: Self { self.getBits(0...31) }
    var lower32bits: Self { self.getBits(32...63) }

    /// Gets this number's bits without shifting the value down to the LSB
    /// the bits are indexed from MSB at 0 to LSB at 63
    /// example: (0b11010).getBitsUnshifted(0..<4) == 0b110_00
    /// (note: the bits before the _ are the one's gotten)
    func getBitsUnshifted<T: FixedWidthInteger>(_ range: ClosedRange<T>) -> Self {
        guard range.lowerBound >= 0 else {
            fatalError("BSONDecimal128: Your range should be bound between [0, 63] was \(range)")
        }
        guard range.upperBound <= 63 else {
            fatalError("BSONDecimal128: Your range should be bound between [0, 63] was \(range)")
        }
        var value = UInt64()
        for i in range {
            value |= (self & (0b1 << (63 - i)))
        }
        return value
    }

    func getLeastSignificantBits<T: FixedWidthInteger>(_ length: T) -> Self {
        self.getBits((63 - Int(length - 1))...63)
    }

    /// Gets this number's bits shifting the value down to the LSB
    /// the bits are indexed from MSB at 0 to LSB at 63
    /// example: (0b11010).getBitsUnshifted(0..<4) == 0b110
    func getBits<T: FixedWidthInteger>(_ range: ClosedRange<T>) -> Self {
        var value = self.getBitsUnshifted(range)
        value >>= (63 - range.upperBound)
        return value
    }

    func getBit(_ index: Int) -> Self {
        let shiftAmount = 63 - index
        let value = (self >> shiftAmount) & 0b1
        return value
    }

    mutating func setBit(_ index: Int) {
        let shiftAmount = 63 - index
        self |= 1 << shiftAmount
    }
}

private extension Array where Element == UInt8 {
    func decimalDigitsToUInt64() -> UInt64 {
        var value = UInt64()
        guard !self.isEmpty else {
            return value
        }
        value = UInt64(self[0])
        for digit in self[1...] {
            value *= 10
            value += UInt64(digit)
        }
        return value
    }
}

internal struct UInt128: Equatable, Hashable {
    /// The high order 64 bits
    internal var hi: UInt64
    /// The low order 64 bits
    internal var lo: UInt64

    internal init(hi: UInt64, lo: UInt64) {
        self.hi = hi
        self.lo = lo
    }

    internal init() {
        self.hi = 0
        self.lo = 0
    }

    internal func divideBy1Billion() -> (quotient: UInt128, remainder: Int) {
        // swiftlint:disable:previous cyclomatic_complexity
        let denominator: UInt64 = 1000 * 1000 * 1000
        var remainder: UInt64 = 0
        var quotient = self

        guard !(quotient.hi == 0 && quotient.lo == 0) else {
            return (quotient: quotient, remainder: 0)
        }

        for i in 0...3 {
            // Adjust remainder to match value of next dividend
            remainder <<= 32
            // Add the divided to remainder
            var quotientI: UInt64
            switch i {
            case 0: quotientI = quotient.hi.upper32bits
            case 1: quotientI = quotient.hi.lower32bits
            case 2: quotientI = quotient.lo.upper32bits
            case 3: quotientI = quotient.lo.lower32bits
            default: quotientI = 0
            }
            remainder += quotientI
            // quotient[i] = Int(remainder / DIVISOR)
            switch i {
            case 0: quotient.hi = (((remainder / denominator) << 32) | quotient.hi.lower32bits)
            case 1: quotient.hi = ((remainder / denominator).lower32bits | quotient.hi.getBitsUnshifted(0...31))
            case 2: quotient.lo = (((remainder / denominator) << 32) | quotient.lo.lower32bits)
            case 3: quotient.lo = ((remainder / denominator).lower32bits | quotient.lo.getBitsUnshifted(0...31))
            default: break
            }
            // Store the remainder
            remainder %= denominator
        }

        return (quotient: quotient, remainder: Int(remainder.lower32bits))
    }
}

/// A struct to represent the BSON Decimal128 type.
public struct BSONDecimal128: Equatable, Hashable, CustomStringConvertible {
    // swiftlint:disable line_length
    private static let digitsRegex = #"(?:\d+)"#
    private static let indicatorRegex = #"(?:e)"#
    private static let signRegex = #"[+-]"#
    private static let infinityRegex = #"infinity|inf"#
    private static let decimalRegex = "\(digitsRegex)\\.\(digitsRegex)?|\\.?\(digitsRegex)"
    private static let nanRegex = #"NaN"#
    private static let exponentRegex = "\(indicatorRegex)(\(signRegex))?(\(digitsRegex))"
    private static let numericValueRegex = "(\(signRegex))?(?:(\(decimalRegex))(?:\(exponentRegex))?|(\(infinityRegex)))"
    private static let decimal128Regex = "^\(numericValueRegex)$|^(\(nanRegex))$"
    // swiftlint:enable line_length

    /// The precision of the Decimal128 format
    private static let maxSignificandDigits = 34
    /// NOTE: the min and max values are adjusted for when the decimal point is rounded out
    /// e.g, 1.000...*10^-6143 == 1000...*10^-6176
    /// In the spec exp_max is 6144 so we use 6111
    private static let exponentMax = 6111
    /// In the spec exp_min is -6134 so we use -6176
    private static let exponentMin = -6176
    /// The sum of the exponent and a constant (bias) chosen to make the biased exponent’s range non-negative.
    private static let exponentBias = 6176

    /// Length in bits of the exponent field
    private static let exponentLength: UInt64 = 14
    /// Length in bits of the trailing significand field
    private static let trailingSignificandLength: UInt64 = 110

    private static let decimalShift17Zeroes: UInt64 = 100_000_000_000_000_000

    private static let negativeInfinity = UInt128(hi: 0xF800_0000_0000_0000, lo: 0)
    private static let infinity = UInt128(hi: 0x7800_0000_0000_0000, lo: 0)
    private static let NaN = UInt128(hi: 0x7C00_0000_0000_0000, lo: 0)

    private enum REGroups: Int, CaseIterable {
        case sign = 1
        case decimalPart = 2
        case exponentSign = 3
        case exponentPart = 4
        case infinity = 5
        case nan = 6
    }

    public var description: String { self.toString() }

    /// Holder for raw decimal128 value
    private let value: UInt128

    /// Indicators in the combination field that determine number type
    private static let combinationNaN = 0b11111
    private static let combinationInfinity = 0b11110

    /// Determines if the value is Not a Number by checking if bits 1-6 are equal to 1 ignoring sign bit
    private var isNaN: Bool { self.value.hi.getBits(1...5) == Self.combinationNaN }
    /// Determines if the value is Infinity  by checking if bits 1-5 are equal to 1 and bit 6 is 0 ignoring sign bit
    private var isInfinity: Bool { self.value.hi.getBits(1...5) == Self.combinationInfinity }
    /// Determines if the value is Negative
    private var isNegative: Bool { self.value.hi.getBit(0) == 1 }

    internal init(fromUInt128 value: UInt128) {
        self.value = value
    }

    /// Initializes a new `BSONDecimal128` from the input string.
    /// - Throws: `BSONError.InvalidArgumentError` if the input is not a valid Decimal128 string.
    public init(_ data: String) throws {
        // swiftlint:disable:previous cyclomatic_complexity
        let regex = try NSRegularExpression(
            pattern: Self.decimal128Regex,
            options: NSRegularExpression.Options.caseInsensitive
        )
        let wholeRepr = NSRange(data.startIndex..<data.endIndex, in: data)
        guard let match: NSTextCheckingResult = regex.firstMatch(in: data, range: wholeRepr) else {
            throw BSONError.InvalidArgumentError(message: "Syntax Error: Invalid Decimal128 string \(data)")
        }

        var sign = 1
        let signRange: NSRange = match.range(at: REGroups.sign.rawValue)
        if signRange.location != NSNotFound, let range = Range(signRange, in: data) {
            sign = String(data[range]) == "-" ? -1 : 1
        }

        let isNaN = match.range(at: REGroups.nan.rawValue)
        if isNaN.location != NSNotFound {
            self.value = Self.NaN
            return
        }

        let isInfinity = match.range(at: REGroups.infinity.rawValue)
        if isInfinity.location != NSNotFound {
            if sign < 0 {
                self.value = Self.negativeInfinity
                return
            }
            self.value = Self.infinity
            return
        }

        var exponentSign = 1
        let exponentSignRange = match.range(at: REGroups.exponentSign.rawValue)
        if exponentSignRange.location != NSNotFound, let range = Range(exponentSignRange, in: data) {
            exponentSign = String(data[range]) == "-" ? -1 : 1
        }

        let decimalPartNSRange = match.range(at: REGroups.decimalPart.rawValue)
        guard decimalPartNSRange.location != NSNotFound,
              let decimalPartRange = Range(decimalPartNSRange, in: data)
        else {
            throw BSONError.InvalidArgumentError(
                message: "Syntax Error: \(data) Missing digits in front of the exponent"
            )
        }
        let decimalPart = String(data[decimalPartRange])

        var leadingZero = true // indicate when we've encountered the first nonzero digit
        var digits: [UInt8] = []

        // construct array of digits (as UInt8s)
        for digit in decimalPart {
            if digit == "." {
                continue
            }
            guard ("0"..."9").contains(digit) else {
                throw BSONError.InvalidArgumentError(
                    message: "Syntax Error: \(digit) is not a digit '0'-'9'"
                )
            }
            if digit == "0" && leadingZero {
                if decimalPart.utf8.count == 1 {
                    digits.append(0)
                    break
                }
                continue
            }
            if digit != "0" && leadingZero {
                // seen a non zero digit
                leadingZero = false
            }
            guard let digitValue = digit.wholeNumberValue else {
                throw BSONError.InvalidArgumentError(
                    message: "Syntax Error: \(digit) cannot be represented in a UInt8"
                )
            }
            digits.append(UInt8(digitValue))
        }

        var exponent = 0
        let exponentPartRange = match.range(at: REGroups.exponentPart.rawValue)
        if exponentPartRange.location != NSNotFound, let range = Range(exponentPartRange, in: data) {
            exponent = exponentSign * (Int(data[range]) ?? 0)
        }
        if let pointIndex = decimalPart.firstIndex(of: ".") {
            // move the exponent by the number of digits after the decimal point
            // so we are looking at an "integer" significand, easier to reason about
            exponent -= decimalPart.distance(from: pointIndex, to: decimalPart.endIndex) - 1
        }

        while exponent > Self.exponentMax && digits.count <= Self.maxSignificandDigits {
            // Clamping upper bound: Exponent is too large, try shifting zeros into the coefficient

            digits.append(0)
            exponent -= 1
        }

        while exponent < Self.exponentMin && !digits.isEmpty {
            // Clamping lower bound: Exponent is too small, try taking zeros off the coefficient

            if digits.count == 1 && digits[0] == 0 {
                exponent = Self.exponentMin
                break
            }

            if digits.last == 0 {
                digits.removeLast()
                exponent += 1
                continue
            }

            if digits.last != 0 {
                // We don't end in a zero and our exponent is too small
                throw BSONError.InvalidArgumentError(message: "Underflow Error: \(data)")
            }
        }

        guard exponent >= Self.exponentMin else {
            throw BSONError.InvalidArgumentError(message: "Underflow Error: \(data)")
        }

        guard exponent <= Self.exponentMax else {
            throw BSONError.InvalidArgumentError(message: "Overflow Error: \(data)")
        }

        guard digits.count <= Self.maxSignificandDigits else {
            throw BSONError.InvalidArgumentError(message: "Overflow Error: \(data)")
        }

        let significandLoDigits = [UInt8](digits.suffix(Self.maxSignificandDigits / 2)).decimalDigitsToUInt64()
        let significandHiDigits = [UInt8](digits.dropLast(Self.maxSignificandDigits / 2)).decimalDigitsToUInt64()

        // Multiply by one hundred quadrillion (note the seventeen zeroes)
        // the product is the significandHiDigits "shifted" up by 17 decimal places
        // we can then add the significandLoDigits to the product to ensure that we have a correctly formed significand
        let product = significandHiDigits.multipliedFullWidth(by: Self.decimalShift17Zeroes)
        var significand = UInt128(hi: product.high, lo: product.low)

        let (result, didOverflow) = significand.lo.addingReportingOverflow(significandLoDigits)
        significand.lo = result

        if didOverflow {
            significand.hi += 1
        }

        let biasedExponent = UInt64(exponent + Self.exponentBias).getLeastSignificantBits(Self.exponentLength)

        var value = UInt128()

        // Normally Decimal(K) encodings would conditionally modify the combination field here
        // based on the most significant bits of the significand.
        // Decimal128 doesn't actually need the extra implicit bits.
        // The entirety of decimal128's range can fit by just encoding the exponent and significand as-is.

        value.hi |= biasedExponent << (63 - Self.exponentLength)
        value.hi |= significand.hi

        value.lo = significand.lo

        if sign < 0 {
            value.hi.setBit(0)
        }

        self.value = value
    }

    private func toString() -> String {
        // swiftlint:disable:previous cyclomatic_complexity
        var exponent: Int
        var significandPrefix: UInt64 = 0

        // If the combination field starts with 0b11 it could be special (NaN/Inf)
        if self.value.hi.getBits(1...2) == 0b11 {
            if self.isInfinity {
                return (self.isNegative ? "-" : "") + "Infinity"
            }
            if self.isNaN {
                return "NaN"
            }
            // The number is neither NaN nor Inf
            // Decimal interchange floating-point formats c,2,ii
            exponent = Int(self.value.hi.getBits(3...(Self.exponentLength + 2)))
            significandPrefix = (self.value.hi.getBit(20) + 0b1000)
        } else {
            // Decimal interchange floating-point formats c,2,i
            exponent = Int(self.value.hi.getBits(1...Self.exponentLength))
            significandPrefix =
                self.value.hi.getBits(
                    (Self.exponentLength + 1)...(Self.exponentLength + 3)
                )
        }

        exponent -= Self.exponentBias

        var significand128 = UInt128()

        // significand prefix (implied bits) combined with removing the combination and sign fields
        significand128.hi = UInt64(
            significandPrefix.getLeastSignificantBits(4) << (Self.trailingSignificandLength - 64))
            | self.value.hi.getLeastSignificantBits(Self.trailingSignificandLength - 64)
        significand128.lo = self.value.lo

        // make a base 10 digits array from significand
        var significandDigits = [Character]()

        var isZero = false

        if significand128.hi == 0 && significand128.lo == 0 {
            isZero = true
        } else if significand128.hi.upper32bits >= 0x20000 {
            /*
             * The significand is non-canonical or zero.
             * In order to preserve compatibility with the densely packed decimal
             * format, the maximum value for the significand of decimal128 is
             * 1e34 - 1.  If the value is greater than 1e34 - 1, the IEEE 754
             * standard dictates that the significand is interpreted as zero.
             */
            isZero = true
        }

        if isZero {
            significandDigits = ["0"]
        } else {
            for _ in 0...(Self.maxSignificandDigits / 9) {
                var (quotient, remainder) = significand128.divideBy1Billion()
                significand128 = quotient
                // We now have the 9 least significant digits.
                for _ in 0...8 {
                    significandDigits.insert(Character(String(remainder % 10, radix: 10)), at: 0)
                    remainder /= 10
                }
            }
        }

        if !isZero, let firstNonZero = significandDigits.firstIndex(where: { $0 != "0" }) {
            significandDigits = [Character](significandDigits.suffix(from: firstNonZero))
        }

        // Exponential - [-]d.ddde(+/-)dd or [-]de(+/-)dd
        // Regular     - ddd.ddd

        /*
         * The adjusted_exponent checks are dictated by the string conversion
         * specification.
         *
         * We must check exponent > 0, because if this is the case, the number
         * has trailing zeros.  However, we *cannot* output these trailing zeros,
         * because doing so would change the precision of the value, and would
         * change stored data if the string converted number is round tripped.
         */
        var representation = self.isNegative ? "-" : ""

        let adjustedExponent = exponent + (significandDigits.count - 1)
        if exponent > 0 || adjustedExponent < -6 {
            // Exponential format
            representation += String(significandDigits[0])
            representation += significandDigits.count > 1 ? "." : ""
            representation += String(significandDigits[1..<significandDigits.count])
            representation += "E"
            representation += String(format: "%+d", adjustedExponent)
        } else {
            // Regular format
            guard exponent != 0 else {
                representation += String(significandDigits)
                return representation
            }

            let pointPosition = significandDigits.count + exponent

            if pointPosition > 0 {
                // number isn't a fraction
                representation += String(significandDigits[0..<pointPosition])
                significandDigits = Array(significandDigits.dropFirst(pointPosition))
            } else {
                representation += "0"
            }

            representation += "."

            if pointPosition < 0 {
                representation += String(repeating: "0", count: abs(pointPosition))
            }

            representation += String(significandDigits)
        }
        return representation
    }
}

extension BSONDecimal128: BSONValue {
    internal static let extJSONTypeWrapperKeys: [String] = ["$numberDecimal"]

    /*
     * Initializes a `Decimal128` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `Decimal128`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not a `Decimal128`.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        // canonical and relaxed extended JSON
        guard let value = try json.value.unwrapObject(withKey: "$numberDecimal", keyPath: keyPath) else {
            return nil
        }
        guard let str = value.stringValue else {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: "Could not parse `Decimal128` from \"\(value)\", " +
                    "input must be a decimal as a string"
            )
        }
        do {
            self = try BSONDecimal128(str)
        } catch {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: error.localizedDescription
            )
        }
    }

    /// Converts this `Decimal128` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        self.toCanonicalExtendedJSON()
    }

    /// Converts this `Decimal128` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        ["$numberDecimal": JSON(.string(self.toString()))]
    }

    internal static var bsonType: BSONType { .decimal128 }

    internal var bson: BSON { .decimal128(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard
            let lo = buffer.readInteger(endianness: .little, as: UInt64.self),
            let hi = buffer.readInteger(endianness: .little, as: UInt64.self)
        else {
            throw BSONError.InternalError(message: "Cannot read 128-bits")
        }
        let decimal128 = Self(fromUInt128: UInt128(hi: hi, lo: lo))
        return .decimal128(decimal128)
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self.value.lo, endianness: .little, as: UInt64.self)
        buffer.writeInteger(self.value.hi, endianness: .little, as: UInt64.self)
    }
}
