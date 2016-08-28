//
//  Handshake.swift
//  SparkShow
//
//  Created by gezhaoyou on 16/8/1.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation

class RtmpHandshake {
    var rtmpSocket:RtmpSocket
    
    init(rtmpSocket:RtmpSocket) {
        self.rtmpSocket = rtmpSocket
    }
    
    // do simple rtmp handshake
    final func doSimpleHandshake() {
        // create C0 and C1
        let c0c1Chunk:NSMutableData = NSMutableData()
        // protocol version
        c0c1Chunk.appendBytes([UInt8(0x03)], length: 1)
        let timestamp: NSTimeInterval = NSDate().timeIntervalSince1970
        // combine 4B timestamp
        c0c1Chunk.appendBytes(Int32(timestamp).bigEndian.bytes, length: 4)
        // 4B 0x00
        let fourZero = [UInt8](count:4, repeatedValue:0x00)
        c0c1Chunk.appendBytes(fourZero, length: fourZero.count)
        // 1528B random number
        for _ in 1...1528 {
            c0c1Chunk.appendBytes([UInt8(arc4random_uniform(0xff))], length: 1)
        }
        rtmpSocket.write(data: c0c1Chunk)
        
        // read 1B s0, 1536B s1, 1536B s2.
        var s0s1s2:[UInt8] = [UInt8](count: 3073, repeatedValue: 0x00)
        rtmpSocket.read(&s0s1s2, maxLength: 3073)
        
        // send 1536B C2, C2 smae with S1
        let c2Chunk = Array(s0s1s2[1...1536])
        rtmpSocket.write(bytes: c2Chunk)
    }
    
    
    private func doComplexHandshake() {
        // not support yet.
    }
}
