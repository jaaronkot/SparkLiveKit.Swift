//
//  ByteArrayInputStream.swift
//  SparkShow
//
//  Created by gezhaoyou on 16/7/28.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation
class ByteArrayInputStream {
    var byteArray:[UInt8]
    var currentPos:Int = 0
    var remainLength:Int {
        return byteArray.count - currentPos
    }
    
    init(byteArray:[UInt8]) {
        self.byteArray = byteArray
    }
    
    // read maxLength bytes data.
    func read(inout buffer:[UInt8], maxLength:Int) {
        if currentPos + maxLength <= byteArray.count {
            for index in 0..<buffer.count {
                buffer[index] = byteArray[currentPos + index]
            }
            currentPos += maxLength
        } else {
            for index in 0..<byteArray.count - currentPos {
                buffer[index] = byteArray[currentPos + index]
            }
            currentPos = byteArray.count
        }
    }
    
    // read data, but don't move position.
    func tryRead(inout buffer:[UInt8], maxLength:Int) {
        if currentPos + maxLength <= byteArray.count {
            for index in 0..<buffer.count {
                buffer[index] = byteArray[currentPos + index]
            }
        } else {
            for index in 0..<byteArray.count - currentPos {
                buffer[index] = byteArray[currentPos + index]
            }
        }
    }
    
    // get 1B data.
    func read() -> UInt8? {
        if currentPos + 1 <= byteArray.count {
            let byteValue = byteArray[currentPos]
            currentPos += 1
            return byteValue
        } else {
            return nil
        }
    }
}
