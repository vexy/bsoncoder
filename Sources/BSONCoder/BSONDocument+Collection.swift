import Foundation

/// An extension of `BSONDocument` to make it conform to the `Collection` protocol.
/// This gives guarantees on non-destructive iteration, and offers an indexed
/// ordering to the key-value pairs in the document.
extension BSONDocument: Collection {
    /// The index type of a document.
    public typealias Index = Int

    /// Returns the start index of the Document.
    public var startIndex: Index {
        0
    }

    /// Returns the end index of the Document.
    public var endIndex: Index {
        self.count
    }

    private func failIndexCheck(_ i: Index) {
        let invalidIndexMsg = "Index \(i) is invalid"
        guard !self.isEmpty && self.startIndex...self.endIndex - 1 ~= i else {
            fatalError(invalidIndexMsg)
        }
    }

    /// Returns the index after the given index for this Document.
    public func index(after i: Index) -> Index {
        // Index must be a valid one, meaning it must exist somewhere in self.keys.
        self.failIndexCheck(i)
        return i + 1
    }

    /// Allows access to a `KeyValuePair` from the `BSONDocument`, given the position of the desired `KeyValuePair` held
    /// within. This method does not guarantee constant-time (O(1)) access.
    public subscript(position: Index) -> KeyValuePair {
        // TODO: This method _should_ guarantee constant-time O(1) access, and it is possible to make it do so. This
        // criticism also applies to key-based subscripting via `String`.
        // See SWIFT-250.
        self.failIndexCheck(position)
        let iter = BSONDocumentIterator(over: self)

        for pos in 0..<position {
            guard (try? iter.nextThrowing()) != nil else {
                fatalError("Failed to advance iterator to position \(pos)")
            }
        }
        guard let (k, v) = iter.next() else {
            fatalError("Failed get current key and value at \(position)")
        }
        return (k, v)
    }

    /// Allows access to a `KeyValuePair` from the `BSONDocument`, given a range of indices of the desired
    /// `KeyValuePair`'s held within. This method does not guarantee constant-time (O(1)) access.
    public subscript(bounds: Range<Index>) -> BSONDocument {
        // TODO: SWIFT-252 should provide a more efficient implementation for this.
        BSONDocumentIterator.subsequence(of: self, startIndex: bounds.lowerBound, endIndex: bounds.upperBound)
    }
}
