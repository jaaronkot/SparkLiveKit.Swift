//
//  Amf0.swift
//  VTToolbox_swift
//
//  Created by gezhaoyou on 16/7/20.
//  Copyright © 2016年 bravovcloud. All rights reserved.
// 

import Foundation

class Amf0Data {
    enum Amf0DataType:UInt8 {
        case Amf0_Number            = 0x00
        case Amf0_Bool              = 0x01
        case Amf0_String            = 0x02
        case Amf0_Object            = 0x03
        case Amf0_MovieClip         = 0x04
        case Amf0_Null              = 0x05
        case Amf0_Undefined         = 0x06
        case Amf0_Reference         = 0x07
        case Amf0_Map               = 0x08
        case Amf0_ObjectEnd         = 0x09
        case Amf0_Array             = 0x0a
        case Amf0_Date              = 0x0b
        case Amf0_LongString        = 0x0c
        case Amf0_Unsupported       = 0x0d
        case Amf0_RecordSet         = 0x0e
        case Amf0_XmlDocument       = 0x0f
        case Amf0_TypedObject       = 0x10
        case Amf0_AVMplushObject    = 0x11
        case Amf0_Originstrictarray = 0x20
        case Amf0_Invalid           = 0x3f
    }
    
    var dataInBytes:[UInt8] = []
    
    var dataLength:Int {
        return  dataInBytes.count
    }
    
    static func create(inputStream:ByteArrayInputStream) -> Amf0Data?{
        guard let amfTypeRawValue = inputStream.read() else {
            return nil
        }
        guard let amf0Type:Amf0DataType = Amf0DataType(rawValue: amfTypeRawValue) else {
            return nil
        }
        var amf0Data:Amf0Data
        switch amf0Type {
        case .Amf0_Number:
            amf0Data = Amf0Number()
        case .Amf0_Bool:
            amf0Data = Amf0Boolean()
        case .Amf0_String:
            amf0Data = Amf0String()
        case .Amf0_Object:
            amf0Data = Amf0Object()
        case .Amf0_Null:
            amf0Data = Amf0Null()
        case .Amf0_Undefined:
            amf0Data = Amf0Undefined()
        case .Amf0_Map:
            amf0Data = Amf0Map()
        case .Amf0_Array:
            amf0Data = Amf0Array()
        default:
            return nil
        }
        amf0Data.decode(inputStream)
        return amf0Data
    }
    
    func decode(inputStream:ByteArrayInputStream) {
        
    }
}

// Amf0 Number
class Amf0Number: Amf0Data {
    var value:Double!
    
    override init() {
        
    }
    
    init(value: Any) {
        switch value {
        case let value as Double:
            self.value = value
        case let value as Int:
            self.value = Double(value)
        case let value as Int32:
            self.value = Double(value)
        case let value as UInt32:
            self.value = Double(value)
        case let value as Float64:
            self.value = Double(value)
        default:
            break
        }
    }
    
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            // 1B type
            super.dataInBytes.append(Amf0DataType.Amf0_Number.rawValue)
            // 8B double value
            super.dataInBytes += value.bytes.reverse()
            return super.dataInBytes
        }
        
        set {
            
        }
    }
    
    override func decode(inputStream:ByteArrayInputStream) {
        // 1B amf type has skip.
        self.value = NumberByteOperator.readDouble(inputStream)
    }
    
    static func decode(inputStream:ByteArrayInputStream) -> Double {
        // skip 1B amf type
        inputStream.read()
        return NumberByteOperator.readDouble(inputStream)
    }
}

// Amf0 Null
class Amf0Null: Amf0Data {
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            // only 1B amf null type, no value
            super.dataInBytes.append(Amf0DataType.Amf0_Null.rawValue)
            return super.dataInBytes
        }
        
        set {
            
        }
    }
}

// Amf0 Boolean
class Amf0Boolean: Amf0Data {
    private var value:Bool = false
    
    override init() {
        
    }
    
    init(value:Bool) {
        self.value = value
    }
    
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            // 1B type
            super.dataInBytes.append(Amf0DataType.Amf0_Bool.rawValue)
            // write value
            super.dataInBytes.append((value ? 0x01 : 0x00))
            return super.dataInBytes
        }
        
        set {
            
        }
    }
    
    override func decode(inputStream:ByteArrayInputStream) {
        // 1B amf type has skip.
        self.value = (inputStream.read() == 0x01)
    }
}

// Amf0 String
class Amf0String: Amf0Data {
    private var value:String!
    override init() {
        
    }
    
    init(value:String) {
        self.value = value
    }
    
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            
            let isLongString:Bool = UInt32(value.characters.count) > UInt32(UInt16.max)
            // 1B type
            super.dataInBytes.append(isLongString ? Amf0DataType.Amf0_LongString.rawValue : Amf0DataType.Amf0_String.rawValue)
            let stringInBytes:[UInt8] = [UInt8](value.utf8)
            // value Length
            if isLongString {
                super.dataInBytes += UInt32(stringInBytes.count).bigEndian.bytes
            } else {
                super.dataInBytes += UInt16(stringInBytes.count).bigEndian.bytes
            }
            // value in bytes
            super.dataInBytes += stringInBytes
            return super.dataInBytes
        }
        
        set {
            
        }
    }
    
    override func decode(inputStream:ByteArrayInputStream) {
        // 1B amf type has skip.
        let stringLength = NumberByteOperator.readUint16(inputStream)
        var stringInbytes:[UInt8] = [UInt8](count: Int(stringLength), repeatedValue: 0x00)
        inputStream.read(&stringInbytes, maxLength: Int(stringLength))

        self.value = String(bytes: stringInbytes, encoding: NSUTF8StringEncoding)
    }
    
    static func decode(inputStream:ByteArrayInputStream, isAmfObjectKey:Bool) -> String? {
        if !isAmfObjectKey {
            // skip 1B Amf type
            inputStream.read()
        }

        let stringLength = NumberByteOperator.readUint16(inputStream)
        var stringInbytes:[UInt8] = [UInt8](count: Int(stringLength), repeatedValue: 0x00)
        inputStream.read(&stringInbytes, maxLength: Int(stringLength))
        return  String(bytes: stringInbytes, encoding: NSUTF8StringEncoding)
    }
}

// Amf0 Object
class Amf0Object: Amf0Data {
    var endMark:[UInt8] = [0x00, 0x00, 0x09]
    var properties:[String: Amf0Data] = [String: Amf0Data]()
    
    func setProperties(key:String, value:Any) {
        switch value {
        case let value as Double:
            properties[key] = Amf0Number(value: value)
        case let value as Int:
            properties[key] = Amf0Number(value: value)
        case let value as String:
            properties[key] = Amf0String(value: value)
        case let value as Bool:
            properties[key] = Amf0Boolean(value: value)
        default:
            properties[key] = Amf0Number(value: value)
            break
        }
    }
    
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            
            // 1B type
            super.dataInBytes.append(Amf0DataType.Amf0_Object.rawValue)
            for (key, value) in properties {
                // append key
                let keyInBytes = [UInt8](key.utf8)
                super.dataInBytes += UInt16(keyInBytes.count).bigEndian.bytes
                super.dataInBytes += keyInBytes
                // append value
                super.dataInBytes += value.dataInBytes
            }
            
            // append amf object end mark.
            super.dataInBytes += endMark
            return super.dataInBytes
        }
        
        set {
            
        }
    }
    
    override func decode(inputStream:ByteArrayInputStream) {
        // 1B amf type has skip.
        var buffer:[UInt8] = [UInt8](count:3, repeatedValue: 0x00)
        while(true) {
            // try read if catch the object end.
            inputStream.tryRead(&buffer, maxLength: 3)
            if buffer[0] == endMark[0] && buffer[1] == endMark[1] && buffer[2] == endMark[2] {
                // todo 最好改进一下
                inputStream.read(&buffer, maxLength: 3)
                break
            }
            
            guard let key = Amf0String.decode(inputStream, isAmfObjectKey: true) else {
                // print error
                return
            }
            guard let value = Amf0Data.create(inputStream) else {
                // log error
                return
            }
            properties[key] = value
        }
    }
}

// Amf0 Arrary
class Amf0Array: Amf0Data {
    private var arrayItems:[Amf0Data] = [Amf0Data]()
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            // todo
            return super.dataInBytes
        }
        
        set {
            
        }
    }
    
    override func decode(inputStream:ByteArrayInputStream) {
        // 1B amf type has skip.
        let arrayCount:UInt32 = NumberByteOperator.readUint32FromArrayStream(inputStream)
        for _ in 1...arrayCount {
            guard let item:Amf0Data = Amf0Data.create(inputStream) else {
                // log error
                return
            }
            arrayItems.append(item)
        }
    }
}

// Amf0 Map
class Amf0Map: Amf0Object {
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            
            // 1B type
            super.dataInBytes.append(Amf0DataType.Amf0_Map.rawValue)
            // append the map items count
            super.dataInBytes += UInt32(properties.count).bigEndian.bytes
            // append map content
            for (key, value) in properties {
                // append key
                super.dataInBytes += [UInt8](key.utf8)
                // append value
                super.dataInBytes += value.dataInBytes
            }
            
            // append map end mark.
            super.dataInBytes += endMark
            return super.dataInBytes
        }
        
        set {
            
        }
    }
    
    override func decode(inputStream:ByteArrayInputStream) {
        super.decode(inputStream)
    }
}

// Amf0 Undefined
class Amf0Undefined: Amf0Data {
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            
            // only 1B amf type
            super.dataInBytes.append(Amf0DataType.Amf0_Undefined.rawValue)
            return super.dataInBytes
        }
        
        set {
            
        }
    }
    
    override func decode(inputStream:ByteArrayInputStream) {
        // 1B amf type has skip.
        // amf type has been read, nothing still need to be decode.
    }
}


