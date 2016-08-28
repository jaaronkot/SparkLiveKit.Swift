//
//  RtmpMessage.swift
//  VTToolbox_swift
//
//  Created by gezhaoyou on 16/7/20.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation

enum MessageType:UInt8 {
    case SetChunkSize     = 0x01
    case Abort            = 0x02
    case Acknowledgement  = 0x03
    case UserControl      = 0x04
    case WindowAckSize    = 0x05
    case SetPeerBandwidth = 0x06
    case Audio            = 0x08
    case Video            = 0x09
    case AMF3Data         = 0x0f
    case AMF3SharedObject = 0x10
    case AMF3Command      = 0x11
    case AMF0Data         = 0x12
    case AMF0SharedObject = 0x13
    case AMF0Command      = 0x14
    case Aggregate        = 0x16
    case Unknown          = 0xff
}

class RTMPMessage {
    /**
     0 1 2 3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     | Message Type  | Payload length                                |
     | (1 byte)      | (3 bytes)                                     |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     | Timestamp                                                     |
     | (4 bytes)                                                     |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     | Stream ID                                     |
     | (3 bytes)                                     |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                    Message Header
     */
    // 1B message type
    var messageType:MessageType!
    // 3B message payload length
    var payLoadLength:Int {
        get {
            return payload.count
        }
        set {
            
        }
    }
    // 4B Timestamp
    var timestamp:UInt32 = 0
    
    // 4B Stream ID
    var messageStreamId:UInt32 = 0
    // message payload
    var payload:[UInt8] = []
    
    init(messageType:MessageType) {
        self.messageType = messageType
    }
    
    init() {
        
    }
    
    static func create(messageType: MessageType) -> RTMPMessage? {
        switch messageType {
        case MessageType.SetChunkSize:
            return RTMPSetChunkSizeMessage()
        case MessageType.Abort:
            return RTMPAbortMessage()
        case MessageType.UserControl:
            return nil
        case MessageType.WindowAckSize:
            return RTMPWindowAckSizeMessage()
        case MessageType.SetPeerBandwidth:
            return RTMPSetPeerBandwidthMessage()
        case MessageType.Audio:
            return RTMPAudioMessage()
        case MessageType.Video:
            return RTMPVideoMessage()
        case MessageType.AMF0Command:
            return RTMPCommandMessage()
        case MessageType.AMF0Data:
            return RTMPDataMessage()
        case MessageType.Acknowledgement:
            return RTMPAcknowledgementMessage()
        default:
            return nil
        }
    }
}
final class RTMPSetChunkSizeMessage: RTMPMessage {
    var chunkSize:Int = 0
    
    override init() {
        super.init(messageType: .SetChunkSize)
    }
    
    init(chunkSize:Int) {
        super.init(messageType: .SetChunkSize)
        self.chunkSize = chunkSize
    }
    
    override var payload: [UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload += Int32(chunkSize).bigEndian.bytes
            return super.payload
        }
        
        set {
            chunkSize = Int(Int32(bytes: newValue).bigEndian)
        }
    }
    
}

final class RTMPAbortMessage: RTMPMessage {
    private var chunkStreamId:Int32!
    override init() {
        super.init(messageType: .Abort)
    }
    
    init(chunkStreamId:Int32) {
        self.chunkStreamId = chunkStreamId
        super.init(messageType: .Abort)
    }
    
    override var payload: [UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload += chunkStreamId.bigEndian.bytes
            return super.payload
        }
        
        // todo
        set {
            
        }
    }
}


//
final class RTMPAcknowledgementMessage: RTMPMessage {
    var sequence:UInt32!
    
    override init() {
        super.init(messageType: .Acknowledgement)
    }
    
    init(sequence:UInt32) {
        self.sequence = sequence
        super.init(messageType: .Acknowledgement)
    }
    
    override var payload: [UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload += sequence.bigEndian.bytes
            return super.payload
        }
        
        // todo
        set {
            
        }
    }
}

final class RTMPWindowAckSizeMessage: RTMPMessage {
    var windowAckSize:UInt32!
    override init() {
        super.init(messageType: .WindowAckSize)
    }
    
    init(windowAckSize:UInt32) {
        self.windowAckSize = windowAckSize
        super.init(messageType: .WindowAckSize)
        super.timestamp = 0
    }
    
    override var payload: [UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload += windowAckSize.bigEndian.bytes
            return super.payload
        }
        
        // todo
        set {
            windowAckSize = UInt32(bytes: newValue).bigEndian
        }
    }

}


// MARK: -
/**
 5.4.5. Set Peer Bandwidth (6)
 */
final class RTMPSetPeerBandwidthMessage: RTMPMessage {
    enum LimitType:UInt8 {
        case Hard    = 0x00
        case Soft    = 0x01
        case Dynamic = 0x02
        case Unknown = 0xFF
    }
    
    var ackWindodwSize:UInt32 = 0
    var limit:LimitType = .Hard
    
    override init() {
        super.init(messageType: .SetPeerBandwidth)
    }
    
    init(ackWindodwSize:UInt32, limitType:LimitType, messageStreamId:UInt32) {
        self.ackWindodwSize = ackWindodwSize
        super.init(messageType: .SetPeerBandwidth)
        super.messageStreamId = messageStreamId
    }
    
    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            
            super.payload += ackWindodwSize.bigEndian.bytes
            super.payload += [limit.rawValue]
            return super.payload
        }
        
        set {
            if (super.payload == newValue) {
                return
            }
            self.ackWindodwSize = UInt32(bytes: Array(newValue[0...3])).bigEndian
            self.limit = LimitType(rawValue: newValue[4])!
        }
    }
}

final class RTMPCommandMessage: RTMPMessage {
    var commandName:String = ""
    var transactionId:Int = 0
    var commandObjects:[Amf0Data] = [Amf0Data]()
    
    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            // command name
            super.payload += Amf0String(value: commandName).dataInBytes
            // transactionId
            super.payload += Amf0Number(value: transactionId).dataInBytes
            
            for object in commandObjects {
                super.payload += object.dataInBytes
            }
            return super.payload
        }
        
        set {
            let inputStream = ByteArrayInputStream(byteArray: newValue)
            // decode command name.
            guard let commandName = Amf0String.decode(inputStream, isAmfObjectKey: false) else {
                // print command name decode error
                return
            }
            self.commandName = commandName
            // decode transaction id.
            self.transactionId = Int(Amf0Number.decode(inputStream))
            
            //
            while inputStream.remainLength > 0 {
                guard let object:Amf0Data  = Amf0Data.create(inputStream) else {
                    //log error
                    return
                }
                commandObjects.append(object)
            }
        }
    }
    override init() {
        super.init(messageType: .AMF0Command)
    }
    
    init(commandName:String, transactionId:Int, messageStreamId:UInt32) {
        super.init(messageType: .AMF0Command)
        super.messageStreamId = messageStreamId
        self.transactionId = transactionId
        self.commandName = commandName
        
    }
}

/**
 * RTMP Data Message
 */

final class RTMPDataMessage: RTMPMessage {
    private var type:String!
    var objects:[Amf0Data] = [Amf0Data]()
    
    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            // data message type.
            super.payload += Amf0String(value: type).dataInBytes
            for object in objects {
                super.payload += object.dataInBytes
            }
            return super.payload
        }
        
        set {
            let inputStream = ByteArrayInputStream(byteArray: newValue)
            // decode command name.
            guard let type = Amf0String.decode(inputStream, isAmfObjectKey: false) else {
                // print command name decode error
                return
            }
            self.type = type
            //
            while inputStream.remainLength > 0 {
                guard let object:Amf0Data  = Amf0Data.create(inputStream) else {
                    //log error
                    return
                }
                objects.append(object)
            }
        }
    }
    
    override init() {
        super.init(messageType: .AMF0Data)
    }
    
    init(type:String, messageStreamId:UInt32) {
        super.init(messageType: .AMF0Data)
        self.type = type
        super.messageStreamId = messageStreamId
    }
}

// RTMP Audio Message
final class RTMPAudioMessage: RTMPMessage {
    override var payload: [UInt8] {
        get {
            return super.payload
        }
        
        set {
            guard super.payload != newValue else {
                return
            }
            
            super.payload = newValue
        }
    }
    
    override init() {
        super.init(messageType: .Audio)
    }
    
    init(audioBuffer:[UInt8], messageStreamId:UInt32) {
        super.init(messageType: .Audio)
        super.messageStreamId = messageStreamId
        // 注意这个地方是否需要深拷贝？？
        self.payload = audioBuffer
    }
}

// RTMP Video Message
final class RTMPVideoMessage: RTMPMessage {
    override var payload: [UInt8] {
        get {
            return super.payload
        }
        
        set {
            guard super.payload != newValue else {
                return
            }
            
            super.payload = newValue
        }
    }
    
    override init() {
        super.init(messageType: .Video)
    }
    
    init(videoBuffer:[UInt8], messageStreamId:UInt32) {
        super.init(messageType: .Video)
        super.messageStreamId = messageStreamId
        // 注意这个地方是否需要深拷贝？？
        self.payload = videoBuffer
    }
}

