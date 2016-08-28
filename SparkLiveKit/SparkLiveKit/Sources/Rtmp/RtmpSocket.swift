//
//  RtmpSocket.swift
//  VTToolbox_swift
//
// Rtmp的底层，Rtmp的握手，收发底层字节数据，ack状态相应等。
//  Created by gezhaoyou on 16/7/20.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation

final class RtmpSocket: NSObject {
    private let rtmpSocketQueue: dispatch_queue_t = dispatch_queue_create(
        "rtmpSocketQueue", DISPATCH_QUEUE_SERIAL
    )

    private var runloop: NSRunLoop?
    private var isServerConnected = false
    
    var totalInputBytes  = 0
    // all output bytes over tcp stream
    var totalOutputBytes = 0
    
    var inChunkSize:Int = 128
    var outChunkSize:Int = 128
    
    private var inputStream:NSInputStream?
    private var outputStream:NSOutputStream?
    
    private var port:Int!
    
    var hostname:String!
    var app:String!
    var stream:String!
    var rtmpUri:NSURL!
    
    init(rtmpUri: NSURL) {
        self.rtmpUri = rtmpUri
    }
    
    // 有问题 rtmp://192.168.9.51/live/ 会崩溃
    private func parseRtmpUrl() {
        self.hostname = self.rtmpUri.host!
        self.port = self.rtmpUri.port == nil ? 1935 : self.rtmpUri.port!.integerValue
        
        //get rtmp app
        let path = self.rtmpUri.path!
        let pattern = "\\w.*(?=/)"
        let regular = try! NSRegularExpression(pattern: pattern, options: .CaseInsensitive)
        let res = regular.matchesInString(path, options: .ReportProgress, range: NSMakeRange(0, path.characters.count))
        self.app = (path as NSString).substringWithRange(res[0].range)

        // rtmp stream
        self.stream = self.rtmpUri.lastPathComponent!
    }
    
    // connect to rtmp server
    func connect() {
        self.parseRtmpUrl()
        NSStream.getStreamsToHostWithName(self.hostname,
                                          port: self.port,
                                          inputStream: &self.inputStream,
                                          outputStream: &self.outputStream
        )
        
        guard let outputStream = self.outputStream, inputStream = self.inputStream else {
            return
        }
    
        self.totalInputBytes = 0
        self.totalOutputBytes = 0

        inputStream.open()
        outputStream.open()
    }
    
    func disconnect() {
        dispatch_async(rtmpSocketQueue) {
            self.inputStream?.close()
            self.outputStream?.close()
            
            self.outputStream = nil
            self.inputStream = nil
            
            // reset rtmp info value.
            RtmpStream.messageStreamId = 0
            self.outChunkSize = 128
            self.inChunkSize = 128
        }
    }
    
    func write(message:RTMPMessage, chunkType:ChunkType, chunkStreamId:UInt16) {
        guard let chunksBuffer:[UInt8] = RtmpChunk.splitMessage(message, chunkSize: self.outChunkSize, chunkType: chunkType, chunkStreamId: chunkStreamId) else {
            return
        }
        self.write(bytes: chunksBuffer)
    }

    // write to server
    func write(data data:NSData) {
        dispatch_async(rtmpSocketQueue) {
            self.write(UnsafePointer<UInt8>(data.bytes), bufferLength: data.length)
        }
    }
    
    func write(bytes bytes:[UInt8]) {
        dispatch_async(rtmpSocketQueue) {
            self.write(UnsafePointer<UInt8>(bytes), bufferLength: bytes.count)
        }
    }
    
    private func write(buffer:UnsafePointer<UInt8>, bufferLength:Int) {
        var totalBytesHasWrite:Int = 0
        while(true) {
            guard let outputStream = self.outputStream else {
                return
            }
            let writeLength:Int = outputStream.write(buffer.advancedBy(totalBytesHasWrite), maxLength: bufferLength - totalBytesHasWrite)
            
            if writeLength < 0 {
                print("data write error!")
                // write error
                break
            }
            totalBytesHasWrite += writeLength
            
            // record total output bytes
            self.totalOutputBytes += writeLength
            
            if bufferLength == totalBytesHasWrite {
                break
            }
        }
    }
    
    // read from rtmp server.
    func read_3_Byte() -> [UInt8] {
        var buffer:[UInt8] = [UInt8](count:3, repeatedValue: 0x00)
        self.read(&buffer, maxLength: 3)
        return buffer
    }
    
    func read() -> UInt8 {
        var buffer:[UInt8] = [UInt8](count:1, repeatedValue: 0x00)
        self.read(&buffer, maxLength: 1)
        return buffer[0]
    }
    
    // TODO: rewrite read function
    func read(inout buffer:[UInt8], maxLength:Int) {
        var readByteCount = 0
        while(true) {
            guard let inputStream = self.inputStream  else {
                return
            }
            if inputStream.hasBytesAvailable {
                let length = inputStream.read(&buffer, maxLength: maxLength)
                if length < 0 {
                    //log read error
                    break
                }
                readByteCount += length
                self.totalInputBytes += length
                if readByteCount == maxLength {
                    break
                }
            }
        }
    }
}
