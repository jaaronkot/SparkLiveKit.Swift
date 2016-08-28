//
//  PublishStream.swift
//  SparkShow
//
//  Created by gezhaoyou on 16/8/1.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation

class RtmpStream {
    var rtmpSocket:RtmpSocket!
    static var messageStreamId:UInt32 = 0
    var isFirstVideoMessage: Bool = true
    var isFirstAudioMessage: Bool = true
    
    init(rtmpSocket:RtmpSocket) {
        self.rtmpSocket = rtmpSocket
    }
    
    // publish(stream)
    func publishStream() {
        let publishStream:RTMPCommandMessage = RTMPCommandMessage(commandName: "publish", transactionId: 0x05, messageStreamId: RtmpStream.messageStreamId)
        publishStream.commandObjects.append(Amf0Null())
        publishStream.commandObjects.append(Amf0String(value: rtmpSocket.stream))
        publishStream.commandObjects.append(Amf0String(value: rtmpSocket.app))
        
        rtmpSocket.write(publishStream, chunkType: .Type_0, chunkStreamId: 0x08)
    }
    
    func setMetaData(metaData:[String: Any]) {
         let setMetaData = RTMPDataMessage(type: "@setDataFrame", messageStreamId: RtmpStream.messageStreamId)
        setMetaData.objects.append(Amf0String(value: "onMetaData"))
        let ecmaArray = Amf0Map()
        for key in metaData.keys {
             ecmaArray.setProperties(key, value: metaData[key])
        }
        setMetaData.objects.append(ecmaArray)
        rtmpSocket.write(setMetaData, chunkType: .Type_0, chunkStreamId: 0x04)
    }
    
    // FCUnpublish stream
    func FCUnpublish() {
        let FCUnpublishCmd = RTMPCommandMessage(commandName: "FCUnpublish", transactionId: 0x06, messageStreamId: RtmpStream.messageStreamId)
        FCUnpublishCmd.commandObjects.append(Amf0Null())
        FCUnpublishCmd.commandObjects.append(Amf0String(value: rtmpSocket.stream))
        rtmpSocket.write(FCUnpublishCmd, chunkType: .Type_1, chunkStreamId: 0x03)
    }
    
    // delete stream
    func deleteStream() {
        let deleteStreamCmd = RTMPCommandMessage(commandName: "deleteStream", transactionId: 0x07, messageStreamId: RtmpStream.messageStreamId)
        deleteStreamCmd.commandObjects.append(Amf0Null())
        deleteStreamCmd.commandObjects.append(Amf0Number(value: RtmpStream.messageStreamId))
        rtmpSocket.write(deleteStreamCmd, chunkType: .Type_1, chunkStreamId: 0x03)
    }
    
    // publish video
    func publishVideo(videoBuffer:[UInt8], timestamp:UInt32) {
        let videoMessage = RTMPVideoMessage(videoBuffer:videoBuffer, messageStreamId: RtmpStream.messageStreamId)
        videoMessage.timestamp = timestamp
        
        let chunkType: ChunkType = isFirstVideoMessage ? .Type_0 : .Type_1
        rtmpSocket.write(videoMessage, chunkType: chunkType, chunkStreamId: RtmpChunk.VideoChannel)
        isFirstVideoMessage = false
    }
    
    // publish audio
    func publishAudio(audioBuffer:[UInt8], timestamp:UInt32) {
        let audioMessage = RTMPAudioMessage(audioBuffer: audioBuffer, messageStreamId: RtmpStream.messageStreamId)
        
        audioMessage.timestamp = timestamp
        let chunkType: ChunkType = isFirstAudioMessage ? .Type_0 : .Type_1
        rtmpSocket.write(audioMessage, chunkType: chunkType, chunkStreamId: RtmpChunk.AudioChannel)
        isFirstAudioMessage = false
    }
}



