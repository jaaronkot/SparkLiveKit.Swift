//
//  RtmpConnection.swift
//  VTToolbox_swift
//
//  Created by gezhaoyou on 16/7/20.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation

class RtmpConnector {
    var rtmpSocket:RtmpSocket!
    var messageReceiver:RtmpReceiver!
    
    init(rtmpSocket:RtmpSocket) {
        self.rtmpSocket = rtmpSocket
        self.messageReceiver = RtmpReceiver(rtmpSocket: rtmpSocket)
    }
    
    // connect App
    func connectApp() {
        let command:RTMPCommandMessage = RTMPCommandMessage(commandName: "connect", transactionId: 0x01, messageStreamId: 0x00)
        let objects:Amf0Object = Amf0Object()
        objects.setProperties("app", value: rtmpSocket.app)
        objects.setProperties("flashVer",value: "FMLE/3.0 (compatible; FMSc/1.0)");
        objects.setProperties("swfUrl", value:"");
        objects.setProperties("tcUrl", value:rtmpSocket.hostname + "/" + rtmpSocket.app);
        objects.setProperties("fpad", value: false);
        objects.setProperties("capabilities", value:239);
        objects.setProperties("audioCodecs", value:3575);
        objects.setProperties("videoCodecs", value:252);
        objects.setProperties("videoFunction",value: 1);
        objects.setProperties("pageUrl",value: "");
        objects.setProperties("objectEncoding",value: 0);
        command.commandObjects.append(objects)
        
        rtmpSocket.write(command, chunkType: .Type_0, chunkStreamId: RtmpChunk.CommandChannel)
        
//        let windowAckSize = RTMPWindowAckSizeMessage(windowAckSize: 2500000)
//        rtmpSocket.write(windowAckSize, chunkType: .Type_0, chunkStreamId: RtmpChunk.ControlChannel)
        // set client out chunk size 1024*8
        rtmpSocket.outChunkSize = 60*1000
        let setChunkSize = RTMPSetChunkSizeMessage(chunkSize: rtmpSocket.outChunkSize)
        
        rtmpSocket.write(setChunkSize, chunkType: . Type_0, chunkStreamId: RtmpChunk.ControlChannel)
        
        
        if messageReceiver.expectCommandMessage(0x01) == nil {
            // log error.
            return
        }
        print("app connect success")
    }
    
    func createStream() {
        // release stream. 
        let releaseStream:RTMPCommandMessage = RTMPCommandMessage(commandName: "releaseStream", transactionId: 2, messageStreamId: 0)
        releaseStream.commandObjects.append(Amf0Null())
        releaseStream.commandObjects.append(Amf0String(value: rtmpSocket.stream))
        rtmpSocket.write(releaseStream, chunkType: .Type_1, chunkStreamId: RtmpChunk.CommandChannel)
        
        // FCPublish
        let FCPublish:RTMPCommandMessage = RTMPCommandMessage(commandName: "FCPublish", transactionId: 0x03, messageStreamId: 0)
        FCPublish.timestamp = 0
        FCPublish.commandObjects.append(Amf0Null())
        FCPublish.commandObjects.append(Amf0String(value: rtmpSocket.stream))
        
        rtmpSocket.write(FCPublish, chunkType: .Type_1, chunkStreamId: RtmpChunk.CommandChannel)
        
        // create stream.
        let createStream:RTMPCommandMessage = RTMPCommandMessage(commandName: "createStream", transactionId: 0x04, messageStreamId: 0)
        createStream.timestamp = 0
        createStream.commandObjects.append(Amf0Null())
        
        rtmpSocket.write(createStream, chunkType: .Type_1, chunkStreamId: RtmpChunk.CommandChannel)
        
        guard let result = messageReceiver.expectCommandMessage(0x04) else {
            // log error
            return
        }
        
        guard let amf0Number = (result.commandObjects[1] as? Amf0Number) else {
            // log error
            return
        }
        
        RtmpStream.messageStreamId = UInt32(amf0Number.value)
        
        print("create stream success!")
    }
}


