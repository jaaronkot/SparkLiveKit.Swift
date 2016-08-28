//
//  AACEncoder.swift
//  SparkShow
//
//  Created by gezhaoyou on 16/8/3.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//
import Foundation
import AVFoundation

// MARK: AudioEncoderDelegate
protocol AACEncoderDelegate: class {
    func onGetAACFormatDescription(formatDescription: CMFormatDescriptionRef?)
    func onGetAACSampleBuffer(sampleBuffer: CMSampleBuffer?)
}

/** 
 - seealso:
 - https://developer.apple.com/library/ios/technotes/tn2236/_index.html
 - https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/MultimediaPG/UsingAudio/UsingAudio.html
 */

final class AACEncoder: NSObject {
    private let aacEncoderQueue:dispatch_queue_t = dispatch_queue_create("AACEncoder", DISPATCH_QUEUE_SERIAL)
    private var isRunning: Bool = false
    weak var delegate: AACEncoderDelegate?
    static let supportedSettingsKeys:[String] = [
        //"muted",
        "bitrate",
        //"profile",
        //"sampleRate", // down,up sampleRate not supported yet #58
    ]
    
    var metaData: [String : Any] {
        var metaData = [String : Any]()
        metaData["audiodatarate"] = bitrate
        metaData["audiosamplerate"] = 44100 // audio sample rate
        metaData["audiosamplesize"] = 16
        metaData["stereo"] = false //立体声（双通道）
        metaData["audiocodecid"] = 10
        return metaData
    }

    var muted:Bool = false
    
    var bitrate:UInt32 = 32*1000 {
        didSet {
            dispatch_async(aacEncoderQueue) {
                guard let converter = self.converter else {
                    return
                }
                var bitrate:UInt32 = self.bitrate * self.inDestinationFormat.mChannelsPerFrame
                AudioConverterSetProperty(converter,
                                          kAudioConverterEncodeBitRate,
                                          UInt32(sizeof(UInt32)),
                                          &bitrate)
            }
        }
    }
    
    private var profile: UInt32 = UInt32(MPEG4ObjectID.AAC_LC.rawValue)
    // 关于音频描述信息的 转换后的 aac相关的包
    private var formatDescription:CMFormatDescriptionRef? {
        didSet {
            if (CMFormatDescriptionEqual(formatDescription, oldValue)) {
                return
            }
            delegate?.onGetAACFormatDescription(formatDescription) //音频同步包
        }
    }

    private var currentBufferList: AudioBufferList? = nil
    //pcm 数据描述信息
    private var inSourceFormat: AudioStreamBasicDescription?
   
    // 是一个输入数据的回调函数。用来喂PCM数据给 Converter
    private var inputDataProc: AudioConverterComplexInputDataProc = {(
        converter:AudioConverterRef,
        ioNumberDataPackets:UnsafeMutablePointer<UInt32>,
        ioData:UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription:UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>>,
        inUserData:UnsafeMutablePointer<Void>) in
        return unsafeBitCast(inUserData, AACEncoder.self).onInputDataForAudioConverter(
            ioNumberDataPackets,
            ioData: ioData,
            outDataPacketDescription: outDataPacketDescription
        )
    }
    
    // what for?
    private func onInputDataForAudioConverter(
        ioNumberDataPackets:UnsafeMutablePointer<UInt32>,
        ioData:UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription:UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>>) -> OSStatus {
        
        if (currentBufferList == nil) {
            ioNumberDataPackets.memory = 0
            return 100
        }
        
        let numBytes:UInt32 = min(
            ioNumberDataPackets.memory * inSourceFormat!.mBytesPerPacket,
            currentBufferList!.mBuffers.mDataByteSize
        )
        
        ioData.memory.mBuffers.mData = currentBufferList!.mBuffers.mData
        ioData.memory.mBuffers.mDataByteSize = numBytes
        ioNumberDataPackets.memory = 1
        currentBufferList = nil
        return noErr
    }

    // input audio stream basic description. by zhaoyou. 目标转换格式
    private var inDestinationFormat: AudioStreamBasicDescription {
        get {
            var format = AudioStreamBasicDescription(mSampleRate: inSourceFormat!.mSampleRate,// 采样率 44100
                                                     mFormatID: kAudioFormatMPEG4AAC, // 压缩编码格式 MPEG4-AAC
                                                     mFormatFlags: UInt32(MPEG4ObjectID.AAC_Main.rawValue),
                                                     mBytesPerPacket: 0,
                                                     mFramesPerPacket: 1024, // AAC 一帧的大小 default： 1024 Bytes
                                                     mBytesPerFrame: 0, //
                                                     mChannelsPerFrame: inSourceFormat!.mChannelsPerFrame, // 采样通道数， ipad4 is 1
                                                     mBitsPerChannel: 0, // 可能是采样位数
                                                     mReserved: 0)//  Pads the structure out to force an even 8-byte alignment. Must be set to 0.
            
            CMAudioFormatDescriptionCreate(kCFAllocatorDefault,
                                           &format,
                                           0,
                                           nil,
                                           0,
                                           nil,
                                           nil,
                                           &formatDescription) // 这个地方第一次给 formatDescription设置值。
            
            return format
        }
        
        set {
            // nothing to do, just let inTargetFormat write able writeable
            // because AudioConverterNewSpecific need it writeable
        }
    }
    private var inClassDescriptions: [AudioClassDescription] = [
        AudioClassDescription(mType:kAudioEncoderComponentType,
                                    mSubType: kAudioFormatMPEG4AAC,
                                    mManufacturer: kAppleSoftwareAudioCodecManufacturer),
        AudioClassDescription(mType:kAudioEncoderComponentType,
                                    mSubType: kAudioFormatMPEG4AAC,
                                    mManufacturer: kAppleHardwareAudioCodecManufacturer)
    ]
    
    private var _converter:AudioConverterRef?
    private var converter:AudioConverterRef? {
        get {
            var status:OSStatus = noErr
            // 创建 AudioConverterRef
            if (_converter == nil) {
                var converter:AudioConverterRef = nil
                status = AudioConverterNewSpecific(&inSourceFormat!,  //原始内容格式
                                                   &self.inDestinationFormat, // 目标转换格式
                                                   UInt32(inClassDescriptions.count),
                                                   &inClassDescriptions,
                                                   &converter)
                if (status == noErr) {
                    //
                    var bitrate:UInt32 = self.bitrate * self.inDestinationFormat.mChannelsPerFrame
                    print("AudioConverterNewSpecific success")
                    // 设置编码输出码率 32kbps
                    AudioConverterSetProperty(converter,
                                              kAudioConverterEncodeBitRate,
                                              UInt32(sizeof(UInt32)),
                                              &bitrate)
                    _converter = converter
                } else {
                    return nil
                }
            }
            return _converter
        }
        
        set {
            if _converter != newValue {
                _converter = newValue
            }
        }
    }

    // what for?
    private func createAudioBufferList(channels:UInt32, size:UInt32) -> AudioBufferList {
        return AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(
            mNumberChannels: channels, mDataByteSize: size, mData: UnsafeMutablePointer<Void>.alloc(Int(size))
            ))
    }
    
    
    func encode(sampleBuffer: CMSampleBuffer) {
        guard isRunning else {
            return
        }
        
        if (inSourceFormat == nil) {
            guard let format:CMAudioFormatDescriptionRef = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                return
            }
            inSourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(format).memory // 获取原始pcm信息
        }
        
        var blockBuffer: CMBlockBuffer?
        currentBufferList = AudioBufferList()
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                                                                nil,
                                                                &currentBufferList!,
                                                                sizeof(AudioBufferList.self),
                                                                nil,
                                                                nil,
                                                                0,
                                                                &blockBuffer)// can't be nil, or the audioData will empty
        
        if (muted) {
            memset(currentBufferList!.mBuffers.mData, 0, Int(currentBufferList!.mBuffers.mDataByteSize))
        }

        var ioOutputDataPacketSize: UInt32 = 1
//        var outputBufferList: AudioBufferList = createAudioBufferList(
//            inDestinationFormat.mChannelsPerFrame, size: 1024
//        )
        
        let frameSize = UInt32(1024)
        let channels = self.inSourceFormat!.mChannelsPerFrame
        let dataPtr = UnsafeMutablePointer<Void>.alloc(Int(frameSize))
        
        let audioBuffer = AudioBuffer(mNumberChannels: channels,
                                      mDataByteSize: frameSize,
                                      mData: dataPtr)
        // free the object which dataPtr reference to
         dataPtr.destroy()
        
        
        var outputBufferList = AudioBufferList(mNumberBuffers: 1,
                                              mBuffers: audioBuffer)
        // here run converter.
        guard let converter = self.converter else { return }

        // 转码方法 AudioConverterFillComplexBuffer： 实现所有音频格式间的转换。@see: http://metoo.blog.51cto.com/7809119/1314560
        let status: OSStatus = AudioConverterFillComplexBuffer(converter,  // 音频转换器
                                                               inputDataProc,
                                                               unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                                                               &ioOutputDataPacketSize,
                                                               &outputBufferList,  //应该是能拿到转换后的音频数据
                                                               nil)
        
         // 判断转换结果
        if status == noErr {
            var outputBuffer: CMSampleBufferRef?
            var timing = CMSampleTimingInfo()
            let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
            CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timing)
            CMSampleBufferCreate(kCFAllocatorDefault,
                                 nil,
                                 false,
                                 nil,
                                 nil,
                                 formatDescription,
                                 numSamples,
                                 1,
                                 &timing,
                                 0,
                                 nil,
                                 &outputBuffer)
            
            CMSampleBufferSetDataBufferFromAudioBufferList(outputBuffer!,
                                                           kCFAllocatorDefault,
                                                           kCFAllocatorDefault,
                                                           0,
                                                           &outputBufferList)
            // 编码后输出的音频包
            delegate?.onGetAACSampleBuffer(outputBuffer)
        }
        
        let list:UnsafeMutableAudioBufferListPointer = UnsafeMutableAudioBufferListPointer(&outputBufferList)
        for buffer in list {
            free(buffer.mData)
        }
    }
    
    func run() {
        isRunning = true
    }
    
    func stop() {
        isRunning = false
        dispatch_async(self.aacEncoderQueue) {
            if self._converter != nil {
                AudioConverterDispose(self._converter!)
                self._converter = nil
            }
            self.inSourceFormat = nil
            self.formatDescription = nil
            self.currentBufferList = nil
        }
    }
}
