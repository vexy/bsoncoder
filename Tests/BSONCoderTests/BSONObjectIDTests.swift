import Foundation

@testable import BSONCoder
import XCTest

extension BSONObjectID {
    // random value
    internal var randomValue: Int {
        var value = Int()
        _ = withUnsafeMutableBytes(of: &value) { self.oid[4..<9].reversed().copyBytes(to: $0) }
        return value
    }

    // counter
    internal var counter: Int {
        var value = Int()
        _ = withUnsafeMutableBytes(of: &value) { self.oid[9..<12].reversed().copyBytes(to: $0) }
        return value
    }
}

final class BSONObjectIDTests {
    func testBSONObjectIDGenerator() {
        let id0 = BSONObjectID()
        let id1 = BSONObjectID()

        // counter should increase by 1
        XCTAssert(id0.counter == id1.counter - 1)
        // check random number doesn't change
        XCTAssert(id0.randomValue == id1.randomValue)
    }

    func testBSONObjectIDRoundTrip() throws {
        let hex = "1234567890ABCDEF12345678" // random hex objectID
        let oid = try BSONObjectID(hex)
        XCTAssert(hex.uppercased() == oid.hex.uppercased())
    }

    func testBSONObjectIDThrowsForBadHex() throws {
        XCTAssertThrowsError(try BSONObjectID("bad1dea"))
    }

    func testFieldAccessors() throws {
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd HH:mm:ss"
        format.timeZone = TimeZone(secondsFromGMT: 0)
        let timestamp = format.date(from: "2020-07-09 16:22:52")
        // 5F07445 is the hex string for the above date
        let oid = try BSONObjectID("5F07445CFBBBBBBBBBFAAAAA")

        XCTAssert(oid.timestamp == timestamp)
        XCTAssert(oid.randomValue == 0xFB_BBBB_BBBB)
        XCTAssert(oid.counter == 0xFAAAAA)
    }

    func testCounterRollover() throws {
        BSONObjectID.generator.counter.store(0xFFFFFF)
        let id0 = BSONObjectID()
        let id1 = BSONObjectID()
        XCTAssert(id0.counter == 0xFFFFFF)
        XCTAssert(id1.counter == 0x0)
    }

    func testTimestampCreation() throws {
        let oid = BSONObjectID()
        let dateFromID = oid.timestamp
        let date = Date()
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd HH:mm:ss"

        XCTAssert(format.string(from: dateFromID) == format.string(from: date))
    }

    /// Test object for testObjectIdJSONCodable
    private struct TestObject: Codable, Equatable {
        private let _id: BSONObjectID

        init(id: BSONObjectID) {
            self._id = id
        }
    }

    func testObjectIdJSONCodable() throws {
        let id = BSONObjectID()
        let obj = TestObject(id: id)
        let output = try JSONEncoder().encode(obj)
        let outputStr = String(decoding: output, as: UTF8.self)
        XCTAssert(outputStr == "{\"_id\":\"\(id.hex)\"}")

        let decoded = try JSONDecoder().decode(TestObject.self, from: output)
        XCTAssert(decoded == obj)

        // expect a decoding error when the hex string is invalid
        let invalidHex = id.hex.dropFirst()
        let invalidJSON = "{\"_id\":\"\(invalidHex)\"}".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(TestObject.self, from: invalidJSON))
    }
}
