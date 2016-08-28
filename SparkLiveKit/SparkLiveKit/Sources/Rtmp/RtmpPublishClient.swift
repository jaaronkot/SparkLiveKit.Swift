//
//  RtmpEngin.swift
//  VTToolbox_swift
//
//  Created by gezhaoyou on 16/7/20.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation

@objc protocol RtmpPublisherDelegate {
//    optional func onServerConnected()
//    optional func onHandshakeDone()
//    optional func onConnectAppDone()
//    optional func onCreateStreamDone()
    optional func onPublishStreamDone()
    // optional func
}

class RtmpPublishClient {
    private var rtmpsocket:RtmpSocket!
    private var publisherQueue: dispatch_queue_t = dispatch_queue_create(
        "RtmpPublishClient", DISPATCH_QUEUE_SERIAL
    )
    private var mediaMetaData: [String : Any]!
    private var rtmpStream: RtmpStream?
    
    var delegate: RtmpPublisherDelegate?
    
    init() {
        
    }
    
    init(rtmpUrl: String) {
        rtmpSocketInit(rtmpUrl)
    }

    func connect(rtmpUrl: String) {
        self.rtmpSocketInit(rtmpUrl)
        self.connect()
    }
    
    private func rtmpSocketInit(rtmpUrl: String) {
        guard let uri:NSURL = NSURL(string: rtmpUrl) else {
            // log error
            return
        }
        rtmpsocket = RtmpSocket(rtmpUri: uri)
    }
    
    func connect() {
        dispatch_async(publisherQueue) {
            self.rtmpsocket.connect()
            // rtmp simple handshake
            let handShake = RtmpHandshake(rtmpSocket: self.rtmpsocket)
            handShake.doSimpleHandshake()
            
            // rtmp connect
            let rtmpConnector = RtmpConnector(rtmpSocket: self.rtmpsocket)
            rtmpConnector.connectApp()
            
            // rtmp create stream
            rtmpConnector.createStream()
            
            // rtmp publish stream.
            self.rtmpStream = RtmpStream(rtmpSocket: self.rtmpsocket)
            self.rtmpStream!.publishStream()
            self.rtmpStream!.setMetaData(self.mediaMetaData)
            self.delegate?.onPublishStreamDone?()
        }
    }
    
    func setMediaMetaData(metaData: [String : Any]) {
        if mediaMetaData == nil {
            mediaMetaData = [String : Any]()
        }
        
        for key in metaData.keys {
            mediaMetaData[key] = metaData[key]
        }
    }
    
    func publishVideo(videoBuffer:[UInt8], timestamp: UInt32) {
        guard let rtmpStream = self.rtmpStream else {
            return
        }
        rtmpStream.publishVideo(videoBuffer, timestamp: timestamp)
    }
    
    func publishAudio(audioBuffer:[UInt8], timestamp: UInt32) {
        guard let rtmpStream = self.rtmpStream else {
            return
        }
        rtmpStream.publishAudio(audioBuffer, timestamp: timestamp)
    }
    
    func stop() {
        dispatch_async(publisherQueue) {
            if let rtmpStream = self.rtmpStream {
                rtmpStream.FCUnpublish()
                rtmpStream.deleteStream()
            }
            self.rtmpsocket.disconnect()
        }
    }
}
