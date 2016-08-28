//
//  AVMuxer.swift
//  SparkShow
//
//  Created by gezhaoyou on 16/8/5.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation
import AVFoundation

protocol RtmpMuxerDelegate: class {
    func sampleOutput(audio buffer:NSData, timestamp:Double)
    func sampleOutput(video buffer:NSData, timestamp:Double)
}

class RtmpMuxer {
    private var previousDts: CMTime = kCMTimeZero
    private var audioTimestamp:CMTime = kCMTimeZero
    
    weak var delegate: RtmpMuxerDelegate?
    /*************************** video mux ******************************/
    /* AVC Sequence Packet
     * @see http://www.adobe.com/content/dam/Adobe/en/devnet/flv/pdfs/video_file_format_spec_v10.pdf
     * - seealso: http://billhoo.blog.51cto.com/2337751/1557646
     * @see # VIDEODATA
     * AVC Sequence Header:
     * 1. FrameType(high 4bits), should be keyframe(type id = 1)
     * 2. CodecID(low 4bits), should be AVC(type id = 7)
     * @see # AVCVIDEOPACKET
     * 3. AVCVIDEOPACKET:
     *     1.) AVCPacketType(8bits), should be AVC sequence header(type id = 0)
     *     2.) COmposotion Time(24bits), should be 0
     *     3.) AVCDecoderConfigurationRecord(n bits)
     */
    private func createAVCSequenceHeader(formatDescription: CMFormatDescriptionRef) -> NSMutableData? {
        let buffer: NSMutableData = NSMutableData()
        var data:[UInt8] = [UInt8](count: 5, repeatedValue: 0x00)
        // FrameType(4bits) | CodecID(4bits)
        data[0] = FLVFrameType.Key.rawValue << 4 | FLVVideoCodec.AVC.rawValue
        // AVCPacketType(8bits)
        data[1] = FLVAVCPacketType.Seq.rawValue
        // COmposotion Time(24bits)
        data[2...4] = [0x00, 0x00, 0x00]
        buffer.appendBytes(&data, length: data.count)
        // AVCDecoderConfigurationRecord Packet
        guard let atoms:NSDictionary = CMFormatDescriptionGetExtension(formatDescription, "SampleDescriptionExtensionAtoms") as? NSDictionary else {
            return nil
        }
        guard let  AVCDecoderConfigurationRecordPacket: NSData =  atoms["avcC"] as? NSData else {
            return nil
        }
        buffer.appendData(AVCDecoderConfigurationRecordPacket)
        return buffer
    }
    
    func muxAVCFormatDescription(formatDescription:CMFormatDescriptionRef?) {
        guard let formatDescription = formatDescription else {
            return
        }
        guard let AVCSequenceHeader = createAVCSequenceHeader(formatDescription) else {
            return
        }
        
        delegate?.sampleOutput(video: AVCSequenceHeader, timestamp: 0)
    }

    // 视频数据包
    func muxAVCSampleBuffer(sampleBuffer: CMSampleBuffer) {
        guard let block: CMBlockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }
        
        let isKeyframe: Bool = !CFDictionaryContainsKey(unsafeBitCast(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), CFDictionary.self), unsafeBitCast(kCMSampleAttachmentKey_NotSync, UnsafePointer<Void>.self))
        
        var totalLength:Int = 0
        var dataPointer:UnsafeMutablePointer<Int8> = nil
        CMBlockBufferGetDataPointer(block, 0, nil, &totalLength, &dataPointer)
        
        var cto:Int32 = 0
        let pts: CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        var dts: CMTime = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
        
        if (dts == kCMTimeInvalid) {
            dts = pts
        } else {
            cto = Int32((CMTimeGetSeconds(pts) - CMTimeGetSeconds(dts)) * 1000)
        }
        
        let timeDelta: Double = (self.previousDts == kCMTimeZero ? 0 : CMTimeGetSeconds(dts) - CMTimeGetSeconds(self.previousDts)) * 1000
        
        let buffer: NSMutableData = NSMutableData()
        
        var data: [UInt8] = [UInt8](count: 5, repeatedValue: 0x00)
        // FrameType(4bits) | CodecID(4bits)
        data[0] = ((isKeyframe ? UInt8(0x01) : UInt8(0x02)) << 4) | UInt8(0x07)
        // AVCPacketType(8bits)
        data[1] = UInt8(0x01)
        // COmposotion Time(24bits)
        data[2...4] = cto.bigEndian.bytes[1...3]
        
        buffer.appendBytes(&data, length: data.count)
        // H264 NALU Size + NALU Raw Data
        buffer.appendBytes(dataPointer, length: totalLength)
        delegate?.sampleOutput(video: buffer, timestamp: timeDelta)
        previousDts = dts
    }
    
    /***************** aac mux ********************/
    // 音频同步包
    func muxAACFormatDescription(formatDescription: CMFormatDescriptionRef?) {
        guard let formatDescription:CMFormatDescriptionRef = formatDescription else {
            return
        }
        let buffer:NSMutableData = NSMutableData()
        let config:[UInt8] = AudioSpecificConfig(formatDescription: formatDescription).bytes
        // 第 1 个字节高 4 位 |0b1010| 代表音频数据编码类型为 AAC，接下来 2 位 |0b11| 表示采样率为 44kHz，接下来 1 位 |0b1| 表示采样点位数 16bit，最低 1 位 |0b1| 表示双声道
        // data的第二个字节为0，0 则为 AAC 音频同步包，1 则为普通 AAC 数据包
        var data:[UInt8] = [0x00, 0x00]
        // 音频同步包的头 的 第一个字节。
        data[0] =  FLVAudioCodec.AAC.rawValue << 4 | FLVSoundRate.KHz44.rawValue << 2 | FLVSoundSize.Snd16bit.rawValue << 1 | FLVSoundType.Stereo.rawValue
        data[1] = FLVAACPacketType.Seq.rawValue
        buffer.appendBytes(&data, length: data.count)
        buffer.appendBytes(config, length: config.count)
        
        delegate?.sampleOutput(audio: buffer, timestamp: 0)
    }
    
    // aac data pack
    func muxAACSampleBuffer(sampleBuffer: CMSampleBuffer?) {
        guard let sampleBuffer = sampleBuffer else {
            return
        }
        var blockBuffer:CMBlockBufferRef?
        var audioBufferList: AudioBufferList = AudioBufferList()
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer, nil, &audioBufferList, sizeof(AudioBufferList.self), nil, nil, 0, &blockBuffer
        )
        let presentationTimeStamp:CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let delta:Double = (audioTimestamp == kCMTimeZero ? 0 : CMTimeGetSeconds(presentationTimeStamp) - CMTimeGetSeconds(audioTimestamp)) * 1000
        guard let _:CMBlockBuffer = blockBuffer where 0 <= delta else {
            return
        }
        let buffer:NSMutableData = NSMutableData()
        
        // raw -> 表示 发送普通 aac 数据包
        var data:[UInt8] = [0x00, FLVAACPacketType.Raw.rawValue]
        data[0] = FLVAudioCodec.AAC.rawValue << 4 | FLVSoundRate.KHz44.rawValue << 2 | FLVSoundSize.Snd16bit.rawValue << 1 | FLVSoundType.Stereo.rawValue
        
        buffer.appendBytes(&data, length: data.count)
        buffer.appendBytes(audioBufferList.mBuffers.mData, length: Int(audioBufferList.mBuffers.mDataByteSize))
        delegate?.sampleOutput(audio: buffer, timestamp: delta)
        audioTimestamp = presentationTimeStamp
    }
}
