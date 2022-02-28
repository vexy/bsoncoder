# BSONCoder
Spearheaded BSON coder - makes encoding or decoding your `struct`s to `BSON` breazingly easy, fast and secure.

## Installation

### Swift Package Manager
Installation is available via [Swift Package Manager](https://swift.org/package-manager/).  
To install the `BSONCoder` add the following to your `Package.swift` file:

```swift
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "YOUR-PACKAGE",
    dependencies: [
        .package(url: "https://github.com/vexy/bsoncoder", .upToNextMajor(from: "1.0.0"))
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
The library supports use with `Swift 5.1+`.  
The minimum `macOS` version required to build the library is `10.14`.    
The library is tested in continuous integration against `macOS 10.14, Ubuntu 16.04, and Ubuntu 18.04`.

## Example Usage
_**HEAVY WIP**_

```Swift
struct Stuff: Decodable {
    let name: String
    let stuff2: [Data]
}

// ADD MORE CODE
try BSONEncoder.encoder(Stuff.self)
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
