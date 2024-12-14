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
    struct Iterator: IteratorProtocol {
        var curPointer: UnsafePointer<UInt8>
        let endPointer: UnsafePointer<UInt8>

        init(startPointer: UnsafePointer<UInt8>, endPointer: UnsafePointer<UInt8>) {
            self.curPointer = startPointer
            self.endPointer = endPointer
        }

        init(from start: Index, to end: Index) {
            self.init(startPointer: start._rawValue, endPointer: end._rawValue)
        }

        mutating func next() -> UInt8? {
            guard curPointer < endPointer else { return nil }
            defer {
                curPointer = curPointer.advanced(by: MemoryLayout<Element>.stride)
            }
            return curPointer.pointee
        }

        func peek() -> UInt8? {
            guard curPointer < endPointer else { return nil }
            return curPointer.pointee
        }

        mutating func advance() {
            guard curPointer < endPointer else { return }
            curPointer = curPointer.advanced(by: MemoryLayout<Element>.stride)
        }
    }
}
