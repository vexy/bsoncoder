<p align="center">
    Stripped <b>BSON</b> coder makes converting your <code>struct`s</code> to and from <code>BSON</code> easy, fast and secure.
</p>

![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/vexy/bsoncoder?style=for-the-badge)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/vexy/bsoncoder?style=for-the-badge)  

[![RC Build](https://github.com/vexy/bsoncoder/actions/workflows/rc_build.yml/badge.svg?branch=main)](https://github.com/vexy/bsoncoder/actions/workflows/rc_build.yml)
[![Tests](https://github.com/vexy/bsoncoder/actions/workflows/testing.yml/badge.svg?branch=main)](https://github.com/vexy/bsoncoder/actions/workflows/testing.yml)



## Swift Package Manager installation
To install the `BSONCoder` add the following to your `Package.swift` file:

```swift
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "YOUR-PACKAGE",
    dependencies: [
        .package(url: "https://github.com/vexy/bsoncoder", .upToNextMajor(from: "1.0"))
    ],
    targets: [
        .target(name: "MyTarget", dependencies: ["BSONCoder"])
    ]
)
```  

## Example Usage

### Encoding data

```Swift
struct Stuff: Encodable {
    let name: String
    let dataField: [Data]
}

let bsonDoc = try! BSONEncoder().encode(Stuff.self)
// from this point on bsonDoc behaves as typical BSON object
// eg:
bsonDoc["name"] = "some_name"
```

### Decoding data
```Swift
struct Stuff: Decodable {
    let name: String
    let intData: Int
    let intArr: [Int]
}

let bsonStruct = ["someName", 1, [1,2,3]
let myStuff: Stuff = try! BSONEncoder().decode(Stuff.self, from: bsonStruct)

// from this point on myStuff behaves as typical Foundation object
print(myStuff.name)     // prints: someName
print(myStuff.intArr)   // prints: [1,2,3]
```

#### Error handling
Use typical `try...catch` mechanism to catch any errors that may occur during `encode` and `decode` operations.  
Follow code comments for more info on the eror types.

## Swift & OS minimums
The library has the following OS minimum configuration:
- Swift `5.1+` 
- iOS `11.0` 
- macOS `10.14`
    
The library is _tested in CI configuration_ running:
- `iOS 11.0`
- `macOS 10.14`
- `Ubuntu 16.04`
- `Ubuntu 18.04`

**NOTE**:  
> A build warnings may appear if Swift version is less than v5.5. Check [`SwiftNIO`](https://github.com/apple/swift-nio#repository-organization) package for more information on how to handle this warnings.

## Original Library
![original-logo](Resources/originalLogo.png)  
This library is a strip-off from [swift-bson](https://github.com/mongodb/swift-bson) library.

`swift-bson` is released under _Apache License 2.0_ therefore `BSONCoder` preserves the same licence style.  

_Copyright claims:_  
Portions of this library are directly taken from the original repository, however some files undertook substantial changes.  
Follow inline code documents for original Copyright or Licence claims.

---  
Copyright (c) 2022 Vexy | Apache License 2.0  
**PGP** `6302 D860 B74C BD34 6482 DBA2 5187 66D0 8213 DBC0`
