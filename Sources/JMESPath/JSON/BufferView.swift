//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

struct BufferView {
    let start: Index
    let count: Int

    private var baseAddress: UnsafePointer<UInt8> { start._rawValue }

    init(_unchecked components: (start: Index, count: Int)) {
        (start, count) = components
    }

    init(start index: Index, count: Int) {
        precondition(count >= 0, "Count must not be negative")
        self.init(_unchecked: (index, count))
    }

    init(unsafeBaseAddress: UnsafePointer<UInt8>, count: Int) {
        self.init(start: .init(rawValue: unsafeBaseAddress), count: count)
    }

    init?(unsafeBufferPointer buffer: UnsafeBufferPointer<UInt8>) {
        guard let baseAddress = buffer.baseAddress else { return nil }
        self.init(unsafeBaseAddress: baseAddress, count: buffer.count)
    }
}

extension BufferView: Sequence {
    typealias Element = UInt8

    func makeIterator() -> Iterator {
        Iterator(from: self.start, to: self.start.advanced(by: self.count))
    }
}

extension BufferView: Collection {
    typealias SubSequence = Self

    @inline(__always)
    var startIndex: Index { start }

    @inline(__always)
    var endIndex: Index { start.advanced(by: count) }

    @inline(__always)
    var indices: Range<Index> {
        .init(uncheckedBounds: (startIndex, endIndex))
    }

    @inline(__always)
    func _checkBounds(_ position: Index) {
        precondition(
            distance(from: startIndex, to: position) >= 0
                && distance(from: position, to: endIndex) > 0,
            "Index out of bounds"
        )
    }

    @inline(__always)
    func _assertBounds(_ position: Index) {
        #if DEBUG
        _checkBounds(position)
        #endif
    }

    @inline(__always)
    func _checkBounds(_ bounds: Range<Index>) {
        precondition(
            distance(from: startIndex, to: bounds.lowerBound) >= 0
                && distance(from: bounds.lowerBound, to: bounds.upperBound) >= 0
                && distance(from: bounds.upperBound, to: endIndex) >= 0,
            "Range of indices out of bounds"
        )
    }

    @inline(__always)
    func _assertBounds(_ bounds: Range<Index>) {
        #if DEBUG
        _checkBounds(bounds)
        #endif
    }

    @inline(__always)
    func index(after i: Index) -> Index {
        i.advanced(by: +1)
    }

    @inline(__always)
    func index(before i: Index) -> Index {
        i.advanced(by: -1)
    }

    @inline(__always)
    func formIndex(after i: inout Index) {
        i = index(after: i)
    }

    @inline(__always)
    func formIndex(before i: inout Index) {
        i = index(before: i)
    }

    @inline(__always)
    func index(_ i: Index, offsetBy distance: Int) -> Index {
        i.advanced(by: distance)
    }

    @inline(__always)
    func formIndex(_ i: inout Index, offsetBy distance: Int) {
        i = index(i, offsetBy: distance)
    }

    @inline(__always)
    func distance(from start: Index, to end: Index) -> Int {
        start.distance(to: end)
    }

    @inline(__always)
    subscript(position: Index) -> Element {
        get {
            _checkBounds(position)
            return self[unchecked: position]
        }
    }

    @inline(__always)
    subscript(unchecked position: Index) -> Element {
        get {
            position._rawValue.pointee
        }
    }

    @inline(__always)
    subscript(bounds: Range<Index>) -> Self {
        get {
            _checkBounds(bounds)
            return self[unchecked: bounds]
        }
    }

    @inline(__always)
    subscript(unchecked bounds: Range<Index>) -> Self {
        get { BufferView(_unchecked: (bounds.lowerBound, bounds.count)) }
    }

    subscript(bounds: some RangeExpression<Index>) -> Self {
        get {
            self[bounds.relative(to: self)]
        }
    }

    subscript(unchecked bounds: some RangeExpression<Index>) -> Self {
        get {
            self[unchecked: bounds.relative(to: self)]
        }
    }

    subscript(x: UnboundedRange) -> Self {
        get {
            self[unchecked: indices]
        }
    }

}

//MARK: integer offset subscripts

extension BufferView {

    @inline(__always)
    subscript(offset offset: Int) -> Element {
        get {
            precondition(0 <= offset && offset < count)
            return self[uncheckedOffset: offset]
        }
    }

    @inline(__always)
    subscript(uncheckedOffset offset: Int) -> Element {
        get {
            self[unchecked: index(startIndex, offsetBy: offset)]
        }
    }

    func loadUnaligned<T>(
        fromByteOffset offset: Int = 0,
        as: T.Type
    ) -> T {
        guard _isPOD(Element.self) && _isPOD(T.self) else { fatalError() }
        _checkBounds(
            Range(
                uncheckedBounds: (
                    .init(rawValue: baseAddress.advanced(by: offset)),
                    .init(rawValue: baseAddress.advanced(by: offset + MemoryLayout<T>.size))
                )
            )
        )
        return UnsafeRawPointer(baseAddress).loadUnaligned(fromByteOffset: offset, as: T.self)
    }

    func loadUnaligned<T>(
        from index: Index,
        as: T.Type
    ) -> T {
        let o = distance(from: startIndex, to: index)
        return loadUnaligned(fromByteOffset: o, as: T.self)
    }

}

extension BufferView {
    var first: Element? {
        startIndex == endIndex ? nil : self[unchecked: startIndex]
    }

    var last: Element? {
        startIndex == endIndex ? nil : self[unchecked: index(before: endIndex)]
    }
}

extension BufferView {
    func withUnsafeRawPointer<R>(
        _ body: (_ pointer: UnsafeRawPointer, _ count: Int) throws -> R
    ) rethrows -> R {
        try body(UnsafeRawPointer(baseAddress), count)
    }
    func withUnsafePointer<R>(
        _ body: (_ pointer: UnsafePointer<UInt8>, _ count: Int) throws -> R
    ) rethrows -> R {
        try body(baseAddress, count)
    }
}
