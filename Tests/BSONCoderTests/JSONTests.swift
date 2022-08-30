import ExtrasJSON
import Foundation

import NIOCore
@testable import BSONCoder
import XCTest

final class JSONTestCase: XCTestCase {
    let encoder = XJSONEncoder()
    let decoder = XJSONDecoder()

    func testInteger() throws {
        // Initializing a JSON with an int works, but it will be cast to a double.
        let intJSON: JSON = 12
        let encoded = Data(try encoder.encode(intJSON))
        XCTAssert(Double(String(data: encoded, encoding: .utf8)!)! == 12)
    }

    func testDouble() throws {
        let doubleJSON: JSON = 12.3
        let encoded = Data(try encoder.encode(doubleJSON))
        XCTAssert(Double(String(data: encoded, encoding: .utf8)!)! == 12.3)
    }

    func testString() throws {
        let stringJSON: JSON = "I am a String"
        let encoded = Data(try encoder.encode(stringJSON))
        XCTAssert(String(data: encoded, encoding: .utf8) == "\"I am a String\"")
    }

    func testBool() throws {
        let boolJSON: JSON = true
        let encoded = Data(try encoder.encode(boolJSON))
        XCTAssert(String(data: encoded, encoding: .utf8) == "true")
    }

    func testArray() throws {
        let arrayJSON: JSON = ["I am a string in an array"]
        let encoded = Data(try encoder.encode(arrayJSON))
        XCTAssert(String(data: encoded, encoding: .utf8) == "[\"I am a string in an array\"]")
    }

    func testObject() throws {
        let objectJSON: JSON = ["Key": "Value"]
        let encoded = Data(try encoder.encode(objectJSON))
        XCTAssert(String(data: encoded, encoding: .utf8) == "{\"Key\":\"Value\"}")
        XCTAssert(objectJSON.value.objectValue!["Key"]!.stringValue! == "Value")
    }
}
