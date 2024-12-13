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

extension BufferView {
    struct Index {
        let _rawValue: UnsafePointer<UInt8>

        @inline(__always)
        internal init(rawValue: UnsafePointer<UInt8>) {
            _rawValue = rawValue
        }
    }
}

extension BufferView.Index: Equatable {}
extension BufferView.Index: Hashable {}
extension BufferView.Index: Strideable {
    typealias Stride = Int

    @inline(__always)
    func distance(to other: Self) -> Int {
        _rawValue.distance(to: other._rawValue)
    }

    @inline(__always)
    func advanced(by n: Int) -> Self {
        .init(rawValue: _rawValue.advanced(by: n))
    }
}

extension BufferView.Index: Comparable {
    @inline(__always)
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs._rawValue < rhs._rawValue
    }
}

@available(*, unavailable)
extension BufferView.Index: Sendable {}

/*
internal struct BufferViewIndex<Element> {
    let _rawValue: UnsafeRawPointer

    @inline(__always)
    internal init(rawValue: UnsafeRawPointer) {
        _rawValue = rawValue
    }

    @inline(__always)
    var isAligned: Bool {
        (Int(bitPattern: _rawValue) & (MemoryLayout<Element>.alignment - 1)) == 0
    }
}

extension BufferViewIndex: Equatable {}

extension BufferViewIndex: Hashable {}

extension BufferViewIndex: Strideable {
    typealias Stride = Int

    @inline(__always)
    func distance(to other: BufferViewIndex) -> Int {
        _rawValue.distance(to: other._rawValue) / MemoryLayout<Element>.stride
    }

    @inline(__always)
    func advanced(by n: Int) -> BufferViewIndex {
        .init(rawValue: _rawValue.advanced(by: n &* MemoryLayout<Element>.stride))
    }
}

extension BufferViewIndex: Comparable {
    @inline(__always)
    static func < (lhs: BufferViewIndex, rhs: BufferViewIndex) -> Bool {
        lhs._rawValue < rhs._rawValue
    }
}

@available(*, unavailable)
extension BufferViewIndex: Sendable {}
*/
