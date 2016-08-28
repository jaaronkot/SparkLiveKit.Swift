
import Foundation

class NumberByteOperator {
    static func readUint16(inputStream: ByteArrayInputStream) ->UInt16 {
        var bytes = [UInt8](count: 2, repeatedValue: 0x00);
        inputStream.read(&bytes, maxLength: 2)
        return UInt16(bytes: bytes).bigEndian
    }

    static func readUint24FromArrayStream(inputStream: ByteArrayInputStream) ->UInt32 {
        var bytes = [UInt8](count: 3, repeatedValue: 0x00);
        inputStream.read(&bytes, maxLength: 3)
        return UInt32(bytes: [0x00] + bytes).bigEndian
    }

    static func readUint32FromArrayStream(inputStream: ByteArrayInputStream) ->UInt32 {
        var bytes = [UInt8](count: 4, repeatedValue: 0x00);
        inputStream.read(&bytes, maxLength: 4)
        return UInt32(bytes: [0x00] + bytes).bigEndian
    }
    
    static func readDouble(inputStream:ByteArrayInputStream) -> Double {
        var bytes = [UInt8](count: 8, repeatedValue: 0x00);
        inputStream.read(&bytes, maxLength: 8)
       return Double(bytes: bytes.reverse())
    }
}

extension IntegerLiteralConvertible {
    var bytes:[UInt8] {
        var value:Self = self
        return withUnsafePointer(&value) {
            Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(Self.self)))
        }
    }
    
    init(bytes:[UInt8]) {
        self = bytes.withUnsafeBufferPointer {
            return UnsafePointer<`Self`>($0.baseAddress).memory
        }
    }
}
