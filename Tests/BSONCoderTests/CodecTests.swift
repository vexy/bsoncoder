import XCTest

@testable import BSONCoder

final class CodecTests: XCTestCase {
    // generic decoding/encoding errors for error matching. Only the case is considered.
    static let typeMismatchErr = DecodingError._typeMismatch(at: [], expectation: Int.self, reality: 0)
    static let invalidValueErr =
        EncodingError.invalidValue(0, EncodingError.Context(codingPath: [], debugDescription: "dummy error"))
    static let dataCorruptedErr = DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: [], debugDescription: "dummy error"))

    // Testing structured imported from Helpers.swift

    /// Test encoding and decoding non-document BSON.
    func testAnyBSON() throws {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()

        let result = try decoder.decode(Int32.self, fromBSON: BSON.int32(1))
        XCTAssert(result == 1)
        
        let oid = try BSONObjectID("507f1f77bcf86cd799439011")
        let oid_result = try decoder.decode(BSONObjectID.self, fromBSON: BSON.objectID(oid))
        XCTAssert(oid_result == oid)
        
//        let array_result = try decoder.decode(Array.self, fromBSON: [BSON.int32(1), BSON.int32(2)])
//        XCTAssert(array_result == [1, 2])

        XCTAssert(try encoder.encodeFragment(oid) == BSON.objectID(oid))
        XCTAssert(try encoder.encodeFragment([Int32(1), Int32(2)]) == [BSON.int32(1), BSON.int32(2)])
    }

//    /// Test encoding/decoding a variety of structs containing simple types that have
//    /// built in Codable support (strings, arrays, ints, and structs composed of them.)
    func testStructs() throws {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()

        let expected: BSONDocument = [
            "val1": "a",
            "val2": 0,
            "val3": [[1, 2], [3, 4]],
            "val4": ["x": 1, "y": 2],
            "val5": [["x": 1, "y": 2]]
        ]

        XCTAssert(try encoder.encode(TestStruct()) == expected)

        // a basic struct
        let basic1 = BasicStruct(int: 1, string: "hello")
        let basic1Doc: BSONDocument = ["int": 1, "string": "hello"]
        XCTAssert(try encoder.encode(basic1) == basic1Doc)
        XCTAssert(try decoder.decode(BasicStruct.self, from: basic1Doc) == basic1)

        // a struct storing two nested structs as properties
        let basic2 = BasicStruct(int: 2, string: "hi")
        let basic2Doc: BSONDocument = ["int": 2, "string": "hi"]

        let nestedStruct = NestedStruct(s1: basic1, s2: basic2)
        let nestedStructDoc: BSONDocument = ["s1": .document(basic1Doc), "s2": .document(basic2Doc)]
        XCTAssert(try encoder.encode(nestedStruct) == nestedStructDoc)
        XCTAssert(try decoder.decode(NestedStruct.self, from: nestedStructDoc) == nestedStruct)

        // a struct storing two nested structs in an array
        let nestedArray = NestedArray(array: [basic1, basic2])
        let nestedArrayDoc: BSONDocument = ["array": [.document(basic1Doc), .document(basic2Doc)]]
        XCTAssert(try encoder.encode(nestedArray) == nestedArrayDoc)
        XCTAssert(try decoder.decode(NestedArray.self, from: nestedArrayDoc) == nestedArray)

        // one more level of nesting
        let nestedNested = NestedNestedStruct(s: nestedStruct)
        let nestedNestedDoc: BSONDocument = ["s": .document(nestedStructDoc)]
        XCTAssert(try encoder.encode(nestedNested) == nestedNestedDoc)
        XCTAssert(try decoder.decode(NestedNestedStruct.self, from: nestedNestedDoc) == nestedNested)
    }

    struct OptionalsStruct: Codable, Equatable {
        let int: Int?
        let bool: Bool?
        let string: String
    }

    /// Test encoding/decoding a struct containing optional values.
    func testOptionals() throws {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()

        let s1 = OptionalsStruct(int: 1, bool: true, string: "hi")
        let s1Doc: BSONDocument = ["int": 1, "bool": true, "string": "hi"]
        XCTAssert(try encoder.encode(s1) == s1Doc)
        XCTAssert(try decoder.decode(OptionalsStruct.self, from: s1Doc) == s1)

        let s2 = OptionalsStruct(int: nil, bool: true, string: "hi")
        let s2Doc1: BSONDocument = ["bool": true, "string": "hi"]
        XCTAssert(try encoder.encode(s2) == s2Doc1)
        XCTAssert(try decoder.decode(OptionalsStruct.self, from: s2Doc1) == s2)

        // test with key in doc explicitly set to BSONNull
        let s2Doc2: BSONDocument = ["int": .null, "bool": true, "string": "hi"]
        XCTAssert(try decoder.decode(OptionalsStruct.self, from: s2Doc2) == s2)
    }

    struct Numbers: Codable, Equatable {
        let int8: Int8?
        let int16: Int16?
        let uint8: UInt8?
        let uint16: UInt16?
        let uint32: UInt32?
        let uint64: UInt64?
        let uint: UInt?
        let float: Float?

        static let keys = ["int8", "int16", "uint8", "uint16", "uint32", "uint64", "uint", "float"]

        init(
            int8: Int8? = nil,
            int16: Int16? = nil,
            uint8: UInt8? = nil,
            uint16: UInt16? = nil,
            uint32: UInt32? = nil,
            uint64: UInt64? = nil,
            uint: UInt? = nil,
            float: Float? = nil
        ) {
            self.int8 = int8
            self.int16 = int16
            self.uint8 = uint8
            self.uint16 = uint16
            self.uint32 = uint32
            self.uint64 = uint64
            self.uint = uint
            self.float = float
        }
    }

    /// Test encoding where the struct's numeric types are non-BSON
    /// and require conversions.
    func testEncodingNonBSONNumbers() throws {
        let encoder = BSONEncoder()

        let s1 = Numbers(int8: 42, int16: 42, uint8: 42, uint16: 42, uint32: 42, uint64: 42, uint: 42, float: 42)

        let int32 = Int32(42)
        // all should be stored as Int32s, except the float should be stored as a double
        let doc1: BSONDocument = [
            "int8": .int32(int32), "int16": .int32(int32), "uint8": .int32(int32), "uint16": .int32(int32),
            "uint32": .int32(int32), "uint64": .int32(int32), "uint": .int32(int32), "float": 42.0
        ]

        XCTAssert(try encoder.encode(s1) == doc1)

        // check that a UInt32 too large for an Int32 gets converted to Int64
        XCTAssert(try encoder.encode(Numbers(uint32: 4_294_967_295)) == ["uint32": .int64(4_294_967_295)])

        // check that UInt, UInt64 too large for an Int32 gets converted to Int64
        XCTAssert(try encoder.encode(Numbers(uint64: 4_294_967_295)) == ["uint64": .int64(4_294_967_295)])
        XCTAssert(try encoder.encode(Numbers(uint: 4_294_967_295)) == ["uint": .int64(4_294_967_295)])

        // check that UInt, UInt64 too large for an Int64 gets converted to Double
        XCTAssert(try encoder.encode(Numbers(uint64: UInt64(Int64.max) + 1)) == ["uint64": 9_223_372_036_854_775_808.0])
        // on a 32-bit platform, Int64.max + 1 will not fit in a UInt.
        //TODO: Introduce non 32bit support
//        if !BSONTestCase.is32Bit {
//            XCTAssert(try encoder.encode(Numbers(uint: UInt(Int64.max) + 1)) == ["uint": 9_223_372_036_854_775_808.0])
//        }
        //TODO: Adjust Throwing errors
        // check that we fail gracefully with a UInt, UInt64 that can't fit in any type.
//        XCTAssert(try encoder.encode(Numbers(uint64: UInt64.max))).to(throwError(CodecTests.invalidValueErr))
//        // on a 32-bit platform, UInt.max = UInt32.max, which fits in an Int64.
//        if BSONTestCase.is32Bit {
//            XCTAssert(try encoder.encode(Numbers(uint: UInt.max)) == ["uint": 4_294_967_295]))
//        } else {
//            XCTAssert(try encoder.encode(Numbers(uint: UInt.max))).to(throwError(CodecTests.invalidValueErr))
//        }
    }

    /// Test decoding where the requested numeric types are non-BSON
    /// and require conversions.
    func testDecodingNonBSONNumbers() throws {
        let decoder = BSONDecoder()

        // the struct we expect to get back
        let s = Numbers(int8: 42, int16: 42, uint8: 42, uint16: 42, uint32: 42, uint64: 42, uint: 42, float: 42)

        // store all values as Int32s and decode them to their requested types
        var doc1 = BSONDocument()
        for k in Numbers.keys {
            doc1[k] = 42
        }
        let res1 = try decoder.decode(Numbers.self, from: doc1)
        XCTAssert(res1 == s)

        // store all values as Int64s and decode them to their requested types.
        var doc2 = BSONDocument()
        for k in Numbers.keys {
            doc2[k] = .int64(42)
        }

        let res2 = try decoder.decode(Numbers.self, from: doc2)
        XCTAssert(res2 == s)

        // store all values as Doubles and decode them to their requested types
        var doc3 = BSONDocument()
        for k in Numbers.keys {
            doc3[k] = .double(42)
        }

        //TODO: Adjust to throwing functions
//        let res3 = try decoder.decode(Numbers.self, from: doc3)
//        XCTAssert(res3 == s)
//
//        // test for each type that we fail gracefully when values cannot be represented because they are out of bounds
//        XCTAssert(try decoder.decode(Numbers.self, from: ["int8": .int64(Int64(Int8.max) + 1)]))
//            .to(throwError(CodecTests.typeMismatchErr))
//        XCTAssert(try decoder.decode(Numbers.self, from: ["int16": .int64(Int64(Int16.max) + 1)]))
//            .to(throwError(CodecTests.typeMismatchErr))
//        XCTAssert(try decoder.decode(Numbers.self, from: ["uint8": -1])).to(throwError(CodecTests.typeMismatchErr))
//        XCTAssert(try decoder.decode(Numbers.self, from: ["uint16": -1])).to(throwError(CodecTests.typeMismatchErr))
//        XCTAssert(try decoder.decode(Numbers.self, from: ["uint32": -1])).to(throwError(CodecTests.typeMismatchErr))
//        XCTAssert(try decoder.decode(Numbers.self, from: ["uint64": -1])).to(throwError(CodecTests.typeMismatchErr))
//        XCTAssert(try decoder.decode(Numbers.self, from: ["uint": -1])).to(throwError(CodecTests.typeMismatchErr))
//        XCTAssert(try decoder.decode(Numbers.self, from: ["float": .double(Double.greatestFiniteMagnitude)]))
//            .to(throwError(CodecTests.typeMismatchErr))
    }

    struct BSONNumbers: Codable, Equatable {
        let int: Int
        let int32: Int32
        let int64: Int64
        let double: Double
    }

    /// Test that BSON number types are encoded properly, and can be decoded from any type they are stored as
    func testBSONNumbers() throws {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()
        // the struct we expect to get back
        let s = BSONNumbers(int: 42, int32: 42, int64: 42, double: 42)
        XCTAssert(try encoder.encode(s) == [
            "int": 42,
            "int32": .int32(42),
            "int64": .int64(42),
            "double": .double(42)
        ])

        // store all values as Int32s and decode them to their requested types
        let doc1: BSONDocument = ["int": .int32(42), "int32": .int32(42), "int64": .int32(42), "double": .int32(42)]
        XCTAssert(try decoder.decode(BSONNumbers.self, from: doc1) == s)

        // store all values as Int64s and decode them to their requested types
        let doc2: BSONDocument = ["int": .int64(42), "int32": .int64(42), "int64": .int64(42), "double": .int64(42)]
        XCTAssert(try decoder.decode(BSONNumbers.self, from: doc2) == s)

        // store all values as Doubles and decode them to their requested types
        let doc3: BSONDocument = ["int": 42.0, "int32": 42.0, "int64": 42.0, "double": 42.0]
        XCTAssert(try decoder.decode(BSONNumbers.self, from: doc3) == s)
    }

    struct AllBSONTypes: Codable, Equatable {
        let double: Double
        let string: String
        let doc: BSONDocument
        let arr: [BSON]
        let binary: BSONBinary
        let oid: BSONObjectID
        let bool: Bool
        let date: Date
        let ts: BSONTimestamp
        let int32: Int32
        let int64: Int64
        let dec: BSONDecimal128
        let minkey: BSONMinKey
        let maxkey: BSONMaxKey
        let undefined: BSONUndefined
        let null: BSONNull

        public static func factory() throws -> AllBSONTypes {
            AllBSONTypes(
                double: Double(2),
                string: "hi",
                doc: ["x": 1],
                arr: [.int32(1), .int32(2)],
                binary: try BSONBinary(base64: "//8=", subtype: .generic),
                oid: try BSONObjectID("507f1f77bcf86cd799439011"),
                bool: true,
                date: Date(timeIntervalSinceReferenceDate: 5000),
                ts: BSONTimestamp(timestamp: 1, inc: 2),
                int32: 5,
                int64: 6,
                dec: try BSONDecimal128("1.2E+10"),
                minkey: BSONMinKey(),
                maxkey: BSONMaxKey(),
                undefined: BSONUndefined(),
                null: BSONNull()
            )
        }

        // Manually construct a document from this instance for comparision with encoder output.
        public func toDocument() -> BSONDocument {
            [
                "double": .double(self.double),
                "string": .string(self.string),
                "doc": .document(self.doc),
                "arr": .array(self.arr),
                "binary": .binary(self.binary),
                "oid": .objectID(self.oid),
                "bool": .bool(self.bool),
                "date": .datetime(self.date),
                "ts": .timestamp(self.ts),
                "int32": .int32(self.int32),
                "int64": .int64(self.int64),
                "dec": .decimal128(self.dec),
                "minkey": .minKey,
                "maxkey": .maxKey,
                "undefined": .undefined,
                "null": .null
            ]
        }
    }

    /// Test decoding/encoding to all possible BSON types
    func testBSONValues() throws {
        let expected = try AllBSONTypes.factory()

        let decoder = BSONDecoder()
        let extendedJSONDecoder = ExtendedJSONDecoder()

        let doc = expected.toDocument()

        let res = try decoder.decode(AllBSONTypes.self, from: doc)
        XCTAssert(res == expected)

        XCTAssert(try BSONEncoder().encode(expected) == doc)

        // swiftlint:disable line_length
        let base64 = "//8="
        let extjson = """
        {
            "double" : 2.0,
            "string" : "hi",
            "doc" : { "x" : { "$numberLong": "1" } },
            "arr" : [ 1, 2 ],
            "binary" : { "$binary" : { "base64": "\(base64)", "subType" : "00" } },
            "oid" : { "$oid" : "507f1f77bcf86cd799439011" },
            "bool" : true,
            "date" : { "$date" : "2001-01-01T01:23:20Z" },
            "code" : { "$code" : "hi" },
            "codeWithScope" : { "$code" : "hi", "$scope" : { "x" : { "$numberLong": "1" } } },
            "int" : 1,
            "ts" : { "$timestamp" : { "t" : 1, "i" : 2 } },
            "int32" : 5,
            "int64" : 6,
            "dec" : { "$numberDecimal" : "1.2E+10" },
            "minkey" : { "$minKey" : 1 },
            "maxkey" : { "$maxKey" : 1 },
            "regex" : { "$regularExpression" : { "pattern" : "^abc", "options" : "imx" } },
            "symbol" : { "$symbol" : "i am a symbol" },
            "undefined": { "$undefined" : true },
            "dbpointer": { "$dbPointer" : { "$ref" : "some.namespace", "$id" : { "$oid" : "507f1f77bcf86cd799439011" } } },
            "null": null
        }
        """
        // swiftlint:enable line_length

        let res2 = try extendedJSONDecoder.decode(AllBSONTypes.self, from: extjson.data(using: .utf8)!)
        XCTAssert(res2 == expected)
    }

    /// Test decoding extJSON and JSON for standalone values
    func testDecodeScalars() throws {
        let extendedJSONDecoder = ExtendedJSONDecoder()

        XCTAssert(try extendedJSONDecoder.decode(Int32.self, from: "42".data(using: .utf8)!) == Int32(42))
        XCTAssert(try extendedJSONDecoder.decode(Int32.self, from: "{\"$numberInt\": \"42\"}".data(using: .utf8)!) == Int32(42))

        let oid = try BSONObjectID("507f1f77bcf86cd799439011")
        XCTAssert(try extendedJSONDecoder.decode(
            BSONObjectID.self,
            from: "{\"$oid\": \"507f1f77bcf86cd799439011\"}".data(using: .utf8)!
        ) == oid)

        XCTAssert(try extendedJSONDecoder.decode(
            String.self,
            from: "\"somestring\"".data(using: .utf8)!
        ) == "somestring")

        XCTAssert(try extendedJSONDecoder.decode(Int64.self, from: "42".data(using: .utf8)!) == Int64(42))
        XCTAssert(try extendedJSONDecoder.decode(
            Int64.self,
            from: "{\"$numberLong\": \"42\"}".data(using: .utf8)!
        ) == Int64(42))

        XCTAssert(try extendedJSONDecoder.decode(Double.self, from: "42.42".data(using: .utf8)!) == 42.42)
        XCTAssert(try extendedJSONDecoder.decode(
            Double.self,
            from: "{\"$numberDouble\": \"42.42\"}".data(using: .utf8)!
        ) == 42.42)

        XCTAssert(try extendedJSONDecoder.decode(
            BSONDecimal128.self,
            from: "{\"$numberDecimal\": \"1.2E+10\"}".data(using: .utf8)!
        ) == BSONDecimal128("1.2E+10"))

        let binary = try BSONBinary(base64: "//8=", subtype: .generic)
        XCTAssert(
            try extendedJSONDecoder.decode(
                BSONBinary.self,
                from: "{\"$binary\" : {\"base64\": \"//8=\", \"subType\" : \"00\"}}".data(using: .utf8)!
            )
         == binary)

        XCTAssert(try extendedJSONDecoder.decode(BSONDocument.self, from: "{\"x\": 1}".data(using: .utf8)!) == ["x": .int32(1)])

        let ts = BSONTimestamp(timestamp: 1, inc: 2)
        XCTAssert(try extendedJSONDecoder.decode(
            BSONTimestamp.self,
            from: "{ \"$timestamp\" : { \"t\" : 1, \"i\" : 2 } }".data(using: .utf8)!
        ) == ts)

        XCTAssert(try extendedJSONDecoder.decode(BSONMinKey.self, from: "{\"$minKey\": 1}".data(using: .utf8)!) == BSONMinKey())
        XCTAssert(try extendedJSONDecoder.decode(BSONMaxKey.self, from: "{\"$maxKey\": 1}".data(using: .utf8)!) == BSONMaxKey())

        XCTAssertFalse(try extendedJSONDecoder.decode(Bool.self, from: "false".data(using: .utf8)!))
        XCTAssert(try extendedJSONDecoder.decode(Bool.self, from: "true".data(using: .utf8)!))

        XCTAssert(try extendedJSONDecoder.decode([Int].self, from: "[1, 2, 3]".data(using: .utf8)!) == [1, 2, 3])
    }

    // test that Document.init(from decoder: Decoder) works with a non BSON decoder and that
    // Document.encode(to encoder: Encoder) works with a non BSON encoder
    func testDocumentIsCodable() throws {
         let encoder = JSONEncoder()
         let decoder = JSONDecoder()

         let json = """
         {
             "name": "Durian",
             "points": 600,
             "pointsDouble": 600.5,
             "description": "A fruit with a distinctive scent.",
             "array": ["a", "b", "c"],
             "doc": { "x" : 2.0 }
         }
         """

         let expected: BSONDocument = [
             "name": "Durian",
             "points": 600,
             "pointsDouble": 600.5,
             "description": "A fruit with a distinctive scent.",
             "array": ["a", "b", "c"],
             "doc": BSON.document(["x": 2])
         ]

         XCTAssertThrowsError(try decoder.decode(BSONDocument.self, from: json.data(using: .utf8)!))
         XCTAssertThrowsError(try String(data: encoder.encode(expected), encoding: .utf8))
    }

    func testEncodeArray() throws {
        let encoder = BSONEncoder()

        let values1 = [BasicStruct(int: 1, string: "hello"), BasicStruct(int: 2, string: "hi")]
        XCTAssert(try encoder.encode(values1) == [["int": 1, "string": "hello"], ["int": 2, "string": "hi"]])

        let values2 = [BasicStruct(int: 1, string: "hello"), nil]
        XCTAssert(try encoder.encode(values2) == [["int": 1, "string": "hello"], nil])
    }

    struct AnyBSONStruct: Codable, Equatable {
        let x: BSON

        init(_ x: BSON) {
            self.x = x
        }
    }

    // test encoding/decoding BSONs with BSONEncoder and Decoder
    func testBSONIsBSONCodable() throws {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()
        let extendedJSONDecoder = ExtendedJSONDecoder()

        // standalone document
        let doc: BSONDocument = ["y": 1]
        let bsonDoc = BSON.document(doc)
        XCTAssert(try encoder.encode(bsonDoc) == doc)
        XCTAssert(try decoder.decode(BSON.self, from: doc) == bsonDoc)
        XCTAssert(try extendedJSONDecoder.decode(BSON.self, from: doc.toCanonicalExtendedJSONString().data(using: .utf8)!) == bsonDoc)

        // doc wrapped in a struct
        let wrappedDoc: BSONDocument = ["x": bsonDoc]
        XCTAssert(try encoder.encode(AnyBSONStruct(bsonDoc)) == wrappedDoc)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedDoc).x == bsonDoc)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedDoc.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == bsonDoc)

        // values wrapped in an `AnyBSONStruct`
        let double: BSON = 42.0
        XCTAssert(try extendedJSONDecoder.decode(BSON.self, from: "{\"$numberDouble\": \"42\"}".data(using: .utf8)!) == double)

        let wrappedDouble: BSONDocument = ["x": double]
        XCTAssert(try encoder.encode(AnyBSONStruct(double)) == wrappedDouble)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedDouble).x == double)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedDouble.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == double)

        // string
        let string: BSON = "hi"
        XCTAssert(try extendedJSONDecoder.decode(BSON.self, from: "\"hi\"".data(using: .utf8)!) == string)

        let wrappedString: BSONDocument = ["x": string]
        XCTAssert(try encoder.encode(AnyBSONStruct(string)) == wrappedString)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedString).x == string)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedString.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == string)

        // array
        let array: BSON = [1, 2, "hello"]

        let decodedArray = try extendedJSONDecoder.decode(
            BSON.self,
            from: "[{\"$numberLong\": \"1\"}, {\"$numberLong\": \"2\"}, \"hello\"]".data(using: .utf8)!
        ).arrayValue
        XCTAssert(decodedArray != nil)
        XCTAssert(decodedArray?[0] == 1)
        XCTAssert(decodedArray?[1] == 2)
        XCTAssert(decodedArray?[2] == "hello")

        let wrappedArray: BSONDocument = ["x": array]
        XCTAssert(try encoder.encode(AnyBSONStruct(array)) == wrappedArray)
        let decodedWrapped = try decoder.decode(AnyBSONStruct.self, from: wrappedArray).x.arrayValue
        XCTAssert(decodedWrapped?[0] == 1)
        XCTAssert(decodedWrapped?[1] == 2)
        XCTAssert(decodedWrapped?[2] == "hello")

        // binary
        let binary = BSON.binary(try BSONBinary(base64: "//8=", subtype: .generic))

        XCTAssert(
            try extendedJSONDecoder.decode(
                BSON.self,
                from: "{\"$binary\" : {\"base64\": \"//8=\", \"subType\" : \"00\"}}".data(using: .utf8)!
            )
         == binary)

        let wrappedBinary: BSONDocument = ["x": binary]
        XCTAssert(try encoder.encode(AnyBSONStruct(binary)) == wrappedBinary)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedBinary).x == binary)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedBinary.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == binary)

        // BSONObjectID
        let oid = BSONObjectID()
        let bsonOid = BSON.objectID(oid)

        XCTAssert(try extendedJSONDecoder.decode(BSON.self, from: "{\"$oid\": \"\(oid.hex)\"}".data(using: .utf8)!) == bsonOid)

        let wrappedOid: BSONDocument = ["x": bsonOid]
        XCTAssert(try encoder.encode(AnyBSONStruct(bsonOid)) == wrappedOid)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedOid).x == bsonOid)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedOid.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == bsonOid)

        // bool
        let bool: BSON = true

        XCTAssert(try extendedJSONDecoder.decode(BSON.self, from: "true".data(using: .utf8)!) == bool)

        let wrappedBool: BSONDocument = ["x": bool]
        XCTAssert(try encoder.encode(AnyBSONStruct(bool)) == wrappedBool)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedBool).x == bool)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedBool.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == bool)

        // date
        let date = BSON.datetime(Date(timeIntervalSince1970: 5000))

        XCTAssert(try extendedJSONDecoder.decode(
            BSON.self,
            from: "{ \"$date\" : { \"$numberLong\" : \"5000000\" } }".data(using: .utf8)!
        ) == date)

        let wrappedDate: BSONDocument = ["x": date]
        XCTAssert(try encoder.encode(AnyBSONStruct(date)) == wrappedDate)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedDate).x == date)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedDate.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == date)

        let dateEncoder = BSONEncoder()
        dateEncoder.dateEncodingStrategy = .millisecondsSince1970
        XCTAssert(try dateEncoder.encode(AnyBSONStruct(date)) == ["x": 5_000_000])

        let dateDecoder = BSONDecoder()
        dateDecoder.dateDecodingStrategy = .millisecondsSince1970

        // int32
        let int32 = BSON.int32(5)

        XCTAssert(try extendedJSONDecoder.decode(BSON.self, from: "{ \"$numberInt\" : \"5\" }".data(using: .utf8)!) == int32)

        let wrappedInt32: BSONDocument = ["x": int32]
        XCTAssert(try encoder.encode(AnyBSONStruct(int32)) == wrappedInt32)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedInt32).x == int32)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedInt32.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == int32)

        // int
        let int: BSON = 5

        XCTAssert(try extendedJSONDecoder.decode(BSON.self, from: "{ \"$numberLong\" : \"5\" }".data(using: .utf8)!) == int)

        let wrappedInt: BSONDocument = ["x": int]
        XCTAssert(try encoder.encode(AnyBSONStruct(int)) == wrappedInt)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedInt).x == int)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedInt.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == int)

        // int64
        let int64 = BSON.int64(5)

        XCTAssert(try extendedJSONDecoder.decode(BSON.self, from: "{\"$numberLong\":\"5\"}".data(using: .utf8)!) == int64)

        let wrappedInt64: BSONDocument = ["x": int64]
        XCTAssert(try encoder.encode(AnyBSONStruct(int64)) == wrappedInt64)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedInt64).x == int64)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedInt64.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == int64)

        // decimal128
        let decimal = BSON.decimal128(try BSONDecimal128("1.2E+10"))

        XCTAssert(try extendedJSONDecoder.decode(
            BSON.self,
            from: "{ \"$numberDecimal\" : \"1.2E+10\" }".data(using: .utf8)!
        ) == decimal)

        let wrappedDecimal: BSONDocument = ["x": decimal]
        XCTAssert(try encoder.encode(AnyBSONStruct(decimal)) == wrappedDecimal)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedDecimal).x == decimal)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedDecimal.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == decimal)

        // maxkey
        let maxKey = BSON.maxKey

        XCTAssert(try extendedJSONDecoder.decode(BSON.self, from: "{ \"$maxKey\" : 1 }".data(using: .utf8)!) == maxKey)

        let wrappedMaxKey: BSONDocument = ["x": maxKey]
        XCTAssert(try encoder.encode(AnyBSONStruct(maxKey)) == wrappedMaxKey)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedMaxKey).x == maxKey)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedMaxKey.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == maxKey)

        // minkey
        let minKey = BSON.minKey

        XCTAssert(try extendedJSONDecoder.decode(BSON.self, from: "{ \"$minKey\" : 1 }".data(using: .utf8)!) == minKey)

        let wrappedMinKey: BSONDocument = ["x": minKey]
        XCTAssert(try encoder.encode(AnyBSONStruct(minKey)) == wrappedMinKey)
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: wrappedMinKey).x == minKey)
        XCTAssert(try extendedJSONDecoder.decode(
            AnyBSONStruct.self,
            from: wrappedMinKey.toCanonicalExtendedJSONString().data(using: .utf8)!
        ).x == minKey)

        // BSONNull
        XCTAssert(try decoder.decode(AnyBSONStruct.self, from: ["x": .null]).x == BSON.null)
        XCTAssert(try encoder.encode(AnyBSONStruct(.null)) == ["x": .null])
    }

    fileprivate struct IncorrectTopLevelEncode: Encodable {
        let x: BSON

        // An empty encode here is incorrect.
        func encode(to _: Encoder) throws {}

        init(_ x: BSON) {
            self.x = x
        }
    }

    fileprivate struct CorrectTopLevelEncode: Encodable {
        let x: IncorrectTopLevelEncode

        enum CodingKeys: CodingKey {
            case x
        }

        // An empty encode here is incorrect.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.x, forKey: .x)
        }

        init(_ x: BSON) {
            self.x = IncorrectTopLevelEncode(x)
        }
    }

    func testIncorrectEncodeFunction() {
        let encoder = BSONEncoder()

        // A top-level `encode()` problem should throw an error, but any such issues deeper in the recursion should not.
        // These tests are to ensure that we handle incorrect encode() implementations in the same way as JSONEncoder.
        XCTAssertThrowsError(try encoder.encode(IncorrectTopLevelEncode(.null)))
        XCTAssert(try encoder.encode(CorrectTopLevelEncode(.null)) == ["x": [:]])
    }

    func testTopLevelArray() {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()
        XCTAssert(try encoder.encodeFragment([1, 2, 3]) == [1, 2, 3])
        XCTAssert(try decoder.decode([Int].self, fromBSON: [1, 2, 3]) == [1, 2, 3])
    }
}
