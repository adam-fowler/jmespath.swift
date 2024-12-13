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
/*
internal struct BufferViewIterator<Element> {
    var curPointer: UnsafeRawPointer
    let endPointer: UnsafeRawPointer

    init(startPointer: UnsafeRawPointer, endPointer: UnsafeRawPointer) {
        self.curPointer = startPointer
        self.endPointer = endPointer
    }

    init(from start: BufferViewIndex<Element>, to end: BufferViewIndex<Element>) {
        self.init(startPointer: start._rawValue, endPointer: end._rawValue)
    }
}

extension BufferViewIterator: IteratorProtocol {

    mutating func next() -> Element? {
        guard curPointer < endPointer else { return nil }
        defer {
            curPointer = curPointer.advanced(by: MemoryLayout<Element>.stride)
        }
        if _isPOD(Element.self) {
            return curPointer.loadUnaligned(as: Element.self)
        }
        return curPointer.load(as: Element.self)
    }

    func peek() -> Element? {
        guard curPointer < endPointer else { return nil }
        if _isPOD(Element.self) {
            return curPointer.loadUnaligned(as: Element.self)
        }
        return curPointer.load(as: Element.self)
    }

    mutating func advance() {
        guard curPointer < endPointer else { return }
        curPointer = curPointer.advanced(by: MemoryLayout<Element>.stride)
    }
}
*/
