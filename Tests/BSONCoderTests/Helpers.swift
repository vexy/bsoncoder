struct ArrayStruct: Encodable {
    let val1 = [0xBAD1DEA, 0x1DEA]
    let val2 = Array.init(repeating: 0xFADE, count: 0xABA)
}

struct TestStruct: Encodable {
    let val1 = "a"
    let val2 = 0
    let val3 = [[1, 2], [3, 4]]
    let val4 = TestClass2()
    let val5 = [TestClass2()]
}

struct TestClass2: Encodable {
    let x = 1
    let y = 2
}

struct BasicStruct: Codable, Equatable {
    let int: Int
    let string: String
}

struct NestedStruct: Codable, Equatable {
    let s1: BasicStruct
    let s2: BasicStruct
}

struct NestedNestedStruct: Codable, Equatable {
    let s: NestedStruct
}

struct NestedArray: Codable, Equatable {
    let array: [BasicStruct]
}
