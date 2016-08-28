//
//  RtmpStream.swift
//  VTToolbox_swift
//
//  Created by gezhaoyou on 16/7/20.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation

class RtmpReceiver {
    //
    private let rtmpSocket:RtmpSocket
    private var chunkStreams:[UInt16 : RtmpChunk]!
    
    init(rtmpSocket:RtmpSocket) {
        self.rtmpSocket = rtmpSocket
        self.chunkStreams = [UInt16 : RtmpChunk]()
    }
    
    final func recvInterlacedMessage() -> RTMPMessage? {
        // basic header fmt.
        var fmt:UInt8 = 0
        var chunkStreamId:UInt16 = 0
        // current chunk info.
        var chunk:RtmpChunk!
        // current message payload length
        var payLoadLength:Int!
        // message payload has read.
        var payloadBuffer:[UInt8] = []
        
        // read chunk basic header.
        func readBasicHeader() {
            // 1B chunk basic header
            let basicHeader = rtmpSocket.read()
            
            fmt = (basicHeader >> 6) & 0x03
            chunkStreamId = UInt16(basicHeader & 0x3f)

            //2-63, 1B chunk header
            if chunkStreamId > 1 {
                return
            }
            
            //64-319, 2B chunk header
            if chunkStreamId == 0 {
                chunkStreamId = UInt16(rtmpSocket.read()) + 64
            } else if chunkStreamId == 1 {
                //64-65599, 3B chunk header
                var IdInBytes: [UInt8] = [UInt8](count: 2, repeatedValue: 0x00)
                rtmpSocket.read(&IdInBytes, maxLength: 2)
                chunkStreamId = UInt16(IdInBytes[0] | (IdInBytes[1] << 8)) + 64
                
            } else {
                //log error
            }
        }
        
        // read chunk message header.
        func readMessageHeader() {
            // find the previous chunk info. If not find, it's first.
            chunk = chunkStreams[chunkStreamId]
            if chunk == nil {
                chunk = RtmpChunk()
                chunkStreams[chunkStreamId] = chunk
            }
            
            //
            let isFirstChunk = (payLoadLength == nil)
            if  isFirstChunk && (fmt != 0x00) {
                if chunkStreamId == RtmpChunk.ControlChannel && fmt == 0x01 {
                    // Log.w(TAG, "accept cid=2, fmt=1 to make librtmp happy.");
                } else {
                    // must be a RTMP protocol level error.
                }
            }
            
            var hasExtendedTimestamp:Bool = false
            var timestampDelta:UInt32!
            if fmt <= 0x02 {
                // timestamp
                timestampDelta = UInt32(bytes: [0x00] + rtmpSocket.read_3_Byte()).bigEndian
                hasExtendedTimestamp = timestampDelta >= 0xffffff
                if(!hasExtendedTimestamp) {
                    if fmt == 0x00 {
                        chunk.timestamp = timestampDelta
                    } else {
                        chunk.timestamp = (chunk.timestamp)! + timestampDelta
                    }
                }
                
                if fmt <= 0x01 {
                    // payload length
                    payLoadLength = Int(Int32(bytes: [0x00] + rtmpSocket.read_3_Byte()).bigEndian)
                    
                    // message type
                    chunk.messageType = MessageType(rawValue: rtmpSocket.read())
                    if fmt == 0x00 {
                        // message stream id
                        var bytes:[UInt8] = [UInt8](count:4, repeatedValue:0x00)
                        rtmpSocket.read(&bytes, maxLength: 4)
                        // Little-endian format
                        chunk.messageStreamId = UInt32(bytes: bytes)
                    } else {
                        // log read complete
                    }
                }
                
            } else {
                if isFirstChunk && !hasExtendedTimestamp {
                    chunk.timestamp = (chunk.timestamp)! + timestampDelta
                }
            }
            
            // extemded timestamp
            if hasExtendedTimestamp {
                var bytes:[UInt8] = [UInt8](count:4, repeatedValue:0x00)
                rtmpSocket.read(&bytes, maxLength: 4)
                // Big-endian format
                chunk.timestamp = UInt32(bytes: bytes).bigEndian
            }
        }
        
        // message payload.
        func readMessagePayload() {
            var size = payLoadLength - payloadBuffer.count
            size = min(size, rtmpSocket.inChunkSize)
            var bytes:[UInt8] = [UInt8](count: size, repeatedValue: 0x00)
            rtmpSocket.read(&bytes, maxLength: size)
            payloadBuffer += bytes
        }
        
        // start read chunk until get a complete message.
        while(true) {
            readBasicHeader()
            readMessageHeader()
            readMessagePayload()
            if payLoadLength <= 0 {
                // get empty message
                return nil
            }
            
            
            // get complete message
            if payLoadLength == payloadBuffer.count {
                guard let message = RTMPMessage.create(chunk.messageType) else {
                    // log create message error.
                    return nil
                }
                message.payLoadLength = payLoadLength
                message.timestamp = chunk.timestamp
                message.messageStreamId = chunk.messageStreamId
                message.payload = payloadBuffer
                return message
            }
        }
    }
    
    func recvMessage() -> RTMPMessage? {
        guard let message = recvInterlacedMessage() else {
            return nil
        }
        onRecvMessage(message)
        return message
    }
    
    func onRecvMessage(rtmpMessage:RTMPMessage) {
        // todo send ack when total byte > 25000000
        switch rtmpMessage.messageType! {
        case MessageType.WindowAckSize :
            guard let message = rtmpMessage as? RTMPWindowAckSizeMessage else {
                return
            }
            RtmpChunk.inWindowAckSize = message.windowAckSize
        case MessageType.SetChunkSize :
            guard let message = rtmpMessage as? RTMPSetChunkSizeMessage else {
                return
            }
            rtmpSocket.inChunkSize = message.chunkSize
        default:
            // todo user control
            break
        }
    }
    
    func expectCommandMessage(transactionID:Int) -> RTMPCommandMessage? {
        while(true) {
            guard let message = recvMessage() as? RTMPCommandMessage else {
                continue
            }
            
            let commandName = message.commandName
            if commandName == "_result" || commandName == "_error" {
                if transactionID == message.transactionId {
                    return message
                } else {
                    // drop unexpect message.
                }
            } else {
                // drop unexpect message.
            }
        }
    }
}
