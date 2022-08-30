# BSONCoder
Spearheaded **BSON** coder -> makes converting your `struct`s to and from `BSON` easy, fast and secure.

![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/vexy/bsoncoder?style=for-the-badge)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/vexy/bsoncoder?style=for-the-badge)  
  
[![RC Build](https://github.com/vexy/bsoncoder/actions/workflows/rc_build.yml/badge.svg?branch=main)](https://github.com/vexy/bsoncoder/actions/workflows/rc_build.yml)
[![Tests](https://github.com/vexy/bsoncoder/actions/workflows/testing.yml/badge.svg?branch=main)](https://github.com/vexy/bsoncoder/actions/workflows/testing.yml)


# Installation

## Swift Package Manager
Installation is available via [Swift Package Manager](https://swift.org/package-manager/).  
To install the `BSONCoder` add the following to your `Package.swift` file:

```swift
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "YOUR-PACKAGE",
    dependencies: [
        .package(url: "https://github.com/vexy/bsoncoder", .upToNextMajor(from: "0.9"))
    ],
    targets: [
        .target(name: "MyTarget", dependencies: ["BSONCoder"])
    ]
)
```

**QUICK URL dependency:**  
```
https://github.com/vexy/bsoncoder
```

### Swift & OS minimums
The library has the following OS minimum configuration:
- Swift `5.1+` 
- iOS `11.0` 
- macOS `10.14`
    
The library is tested in CI configuration running `iOS 11.0 macOS 10.14, Ubuntu 16.04, and Ubuntu 18.04`.

## Example Usage

```Swift
struct Stuff: Encodable {
    let name: String
    let dataField: [Data]
}

let bsonDoc = try BSONEncoder().encode(Stuff.self)
```

```Swift
struct Stuff: Decodable {
    let name: String
    let intData: Int
    let intArr: [Int]
}

let myStuff: Stuff = try BSONEncoder().decode(Stuff.self, from: ["someName", 1, [1,2,3])
print(myStuff.name)     //someName
print(myStuff.intArr)   //[1,2,3]
```

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
