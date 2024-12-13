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
import Foundation

extension String {
    static func _tryFromUTF8(_ input: BufferView) -> String? {
        input.withUnsafePointer { pointer, capacity in
            _tryFromUTF8(.init(start: pointer, count: capacity))
        }
    }
}

extension String {
    func withBufferView<ResultType>(
        _ body: (BufferView) throws -> ResultType
    ) rethrows -> ResultType {
        guard
            let result = try self.utf8.withContiguousStorageIfAvailable({ bytes in
                try body(BufferView(unsafeBufferPointer: bytes)!)
            })
        else {
            var copy = self
            copy.makeContiguousUTF8()
            return try copy.withBufferView(body)
        }
        return result
    }
}

extension Array where Element == UInt8 {
    func withBufferView<ResultType>(
        _ body: (BufferView) throws -> ResultType
    ) rethrows -> ResultType {
        try self.withUnsafeBufferPointer {
            try body(BufferView(unsafeBufferPointer: $0)!)
        }
    }
}

extension Data {
    func withBufferView<ResultType>(
        _ body: (BufferView) throws -> ResultType
    ) rethrows -> ResultType {
        try self.withUnsafeBytes { bytes in
            try bytes.withMemoryRebound(to: UInt8.self) {
                try body(BufferView(unsafeBufferPointer: $0)!)
            }
        }
    }
}

extension BufferView {
    internal func slice(from startOffset: Int, count sliceCount: Int) -> BufferView {
        precondition(
            startOffset >= 0 && startOffset < count && sliceCount >= 0
                && sliceCount <= count && startOffset &+ sliceCount <= count
        )
        return uncheckedSlice(from: startOffset, count: sliceCount)
    }

    internal func uncheckedSlice(from startOffset: Int, count sliceCount: Int) -> BufferView {
        let address = startIndex.advanced(by: startOffset)
        return BufferView(start: address, count: sliceCount)
    }

    internal subscript(region: JSONMap.Region) -> BufferView {
        slice(from: region.startOffset, count: region.count)
    }

    internal subscript(unchecked region: JSONMap.Region) -> BufferView {
        uncheckedSlice(from: region.startOffset, count: region.count)
    }
}
