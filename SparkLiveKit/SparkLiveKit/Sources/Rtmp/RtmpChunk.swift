//
//  RtmpChunk.swift
//  VTToolbox_swift
// 这里面用来 对消息进行分块，和接收消息
//  Created by gezhaoyou on 16/7/20.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation

enum ChunkType:UInt8 {
    case Type_0 = 0
    case Type_1 = 1
    case Type_2 = 2
    case Type_3 = 3
}

final class RtmpChunk {
    static let ControlChannel:UInt16 = 0x02
    static let CommandChannel:UInt16 = 0x03
    
    static let AudioChannel:UInt16   = 0x05
    static let VideoChannel:UInt16   = 0x06
    
    static var inWindowAckSize:UInt32!
    static var outWindowAckChunkSize:UInt32 = 2500*1000
    
    /* chunk basic header. */
    // chunk type -> fmt
    var chunkType: ChunkType = .Type_0
    // chunk stream ID
    var chunkStreamId: UInt16 = 0
    
    /* chunk message header info. */
    // 4B Timestamp
    var timestamp: UInt32!
    // 4B Stream ID
    var messageStreamId: UInt32!
    // 1B message Type
    var messageType: MessageType!
    
    // split message into chunks
    static func splitMessage(message: RTMPMessage, chunkSize: Int, chunkType: ChunkType, chunkStreamId: UInt16) -> [UInt8]? {
        var buffer:[UInt8] = []
        
        // chunk basic header, just use chunkstream id < 64
        switch chunkType {
        case .Type_0:
            buffer += [0x00 << 6 | UInt8(chunkStreamId & 0x3f)]
        case .Type_1:
            buffer += [0x01 << 6 | UInt8(chunkStreamId & 0x3f)]
        default:
            break
        }
        
        // message header
        // 3B timestamp
        buffer += (message.timestamp >= 0xffffff ? [0xff, 0xff, 0xff] : message.timestamp.bigEndian.bytes[1...3])
        
        // 3B payload length
        buffer += UInt32(message.payLoadLength).bigEndian.bytes[1...3]
        // 1B message type
        buffer.append(message.messageType.rawValue)
        // only type 0 has the message stream id.
        if chunkType == .Type_0 {
            // 4B message stream id
            buffer += message.messageStreamId.littleEndian.bytes
        }
        
        // 4B extended timestamp
        if (message.timestamp >= 0xffffff) {
            buffer += message.timestamp.bigEndian.bytes
        }
        
        // start split message payload.
        if message.payLoadLength < chunkSize {
            buffer += message.payload
            return buffer
        }
        
        var remainingCount = message.payLoadLength
        var pos = 0
        while(remainingCount > chunkSize) {
            buffer += message.payload[pos..<(pos + chunkSize)]
            remainingCount -= chunkSize
            pos += chunkSize
            // chunk type 3 header
            buffer.append(UInt8(0xc0 | (chunkStreamId & 0x3f)))
        }
        // append reset payload data.
        buffer += message.payload[pos..<(pos + remainingCount)]
        return buffer
    }
}














