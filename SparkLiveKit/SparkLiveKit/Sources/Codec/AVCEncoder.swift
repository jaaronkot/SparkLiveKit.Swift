//
//  AVCEncoder.swift
//  VTToolbox_swift
//
//  Created by gezhaoyou on 16/7/7.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

// import Foundation
import AVFoundation
import VideoToolbox
import CoreFoundation

protocol AVCEncoderDelegate: class {
    func onGetAVCFormatDescription(formatDescription: CMFormatDescriptionRef?)
    func onGetAVCSampleBuffer(sampleBuffer: CMSampleBuffer)
}

final class AVCEncoder: NSObject {
    static let supportedSettingsKeys:[String] = [
        "width",
        "height",
        "fps",
        "bitrate",
        "keyFrameIntervalDuration",
        ]
    
    private var encoderQueue: dispatch_queue_t = dispatch_queue_create("AVCEncoder", DISPATCH_QUEUE_SERIAL)
    /* encoder session rely on width and height ,when it changed we must regenerate the session */
    // Encoder output video width.
    var metaData: [String : Any] {
        var metaData = [String : Any]()
        metaData["duration"] = keyFrameIntervalDuration // not sure
        metaData["width"] = width
        metaData["height"] = height
        metaData["videodatarate"] = bitrate//bitrate
        metaData["framerate"] = fps // fps
        metaData["videocodecid"] = 7// avc is 7
        return metaData
    }
    
    var width: Int32 = 1280 {
        didSet {
            if self.width == oldValue {
                return
            }
            dispatch_async(encoderQueue) {
                if self.session == nil {
                    return
                }
                self.configSession()
            }
        }
    }
    
    // Encoder output video height.
    var height: Int32 = 720 {
        didSet {
            if self.height == oldValue {
                return
            }
            dispatch_async(encoderQueue) {
                if self.session == nil {
                    return
                }
                self.configSession()
            }
        }
    }
    
    var videoOrientation: AVCaptureVideoOrientation = .Portrait {
        didSet {
            if videoOrientation == oldValue {
                return
            }
            let tmp = self.height
            self.height = self.width
            self.width = tmp
        }
    }
    
    // default 25fps
    var fps: Float64 = 25 {
        didSet {
            if self.fps == oldValue {
                return
            }
            dispatch_async(encoderQueue) {
                guard let session: VTCompressionSessionRef = self.session else {
                    return
                }
                 VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameInterval, self.fps)
                 VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, self.fps)
             }
        }
    }
    
    // @see about bitrate: https://zh.wikipedia.org/wiki/%E6%AF%94%E7%89%B9%E7%8E%87
    var bitrate: UInt32 = 200 * 1000 {
        didSet {
            if self.bitrate == oldValue {
                return
            }
            dispatch_async(encoderQueue) {
                guard let session: VTCompressionSessionRef = self.session else {
                    return
                }
                // when bitrate changed, we must reset it
                let                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             number: CFNumberRef = CFNumberCreate(nil, .SInt32Type, &self.bitrate)
                VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, number)
            }
        }
    }
    
    // key frame interval duration, unit second.
    var keyFrameIntervalDuration: Double = 2.0 {
        didSet {
            if self.keyFrameIntervalDuration == oldValue {
                return
            }
            dispatch_async(encoderQueue) {
                guard let session = self.session else {
                    return
                }
                VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, NSNumber(double: self.keyFrameIntervalDuration))
            }
        }
    }
    
    weak var delegate: AVCEncoderDelegate?
    private var session: VTCompressionSessionRef?
    // recoder previous format description.
    private var formatDescription: CMFormatDescriptionRef?
  
    private var callback: VTCompressionOutputCallback = {(
        outputCallbackRefCon:UnsafeMutablePointer<Void>,
        sourceFrameRefCon:UnsafeMutablePointer<Void>,
        status:OSStatus,
        infoFlags:VTEncodeInfoFlags,
        sampleBuffer:CMSampleBuffer?
        ) in
        guard let sampleBuffer:CMSampleBuffer = sampleBuffer where status == noErr else {
            return
        }
        
        // print("get h.264 data!")
        let encoder: AVCEncoder = unsafeBitCast(outputCallbackRefCon, AVCEncoder.self)
        
        let isKeyframe = !CFDictionaryContainsKey(unsafeBitCast(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), CFDictionary.self), unsafeBitCast(kCMSampleAttachmentKey_NotSync, UnsafePointer<Void>.self))
        
        if isKeyframe {
            let description = CMSampleBufferGetFormatDescription(sampleBuffer)
            if  !CMFormatDescriptionEqual(description, encoder.formatDescription) {
                encoder.delegate?.onGetAVCFormatDescription(description)
                encoder.formatDescription = description
            }
        }
        // get h264 frame
        encoder.delegate?.onGetAVCSampleBuffer(sampleBuffer)
    }
    
    private func configSession() {
        if let session = self.session {
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }
        
        let attributes:[NSString: AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), // not sure zhaoyou
            kCVPixelBufferIOSurfacePropertiesKey: [:],
            kCVPixelBufferOpenGLESCompatibilityKey: true,
            kCVPixelBufferHeightKey: NSNumber(int: height),
            kCVPixelBufferWidthKey: NSNumber(int: width),
            ]
        
        // create encoding session
        VTCompressionSessionCreate(
            kCFAllocatorDefault,
            height, // encode height 宽和高设置反了，只能看到视频中间部分图像
            width,// encode width
            kCMVideoCodecType_H264,  // encode format.
            nil,
            attributes,
            nil,
            callback, // when encode success, callback this.
            unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
            &session)
        
        // don't understand what for, but can be use ???  zhaoyou 16 - 08 - 05
        let profileLevel:String = kVTProfileLevel_H264_Baseline_3_1 as String
        let isBaseline:Bool = profileLevel.containsString("Baseline")
   
        var properties: [NSString: NSObject] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profileLevel,
            kVTCompressionPropertyKey_AverageBitRate: Int(bitrate), // bit rate.
            kVTCompressionPropertyKey_ExpectedFrameRate: NSNumber(double: fps), // frame rate.
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: NSNumber(double: keyFrameIntervalDuration), // key frame interval.
            kVTCompressionPropertyKey_AllowFrameReordering: !isBaseline,
            kVTCompressionPropertyKey_PixelTransferProperties: [
                "ScalingMode": "Trim"
            ]
        ]
        // what for?
        if (!isBaseline) {
            properties[kVTCompressionPropertyKey_H264EntropyMode] = kVTH264EntropyMode_CABAC
        }
        guard let session = session else {
            return
        }
        VTSessionSetProperties(session, properties)
    }
    
    private func enableSession() {
        // set session properties.
        guard let session = session else {
            return
        }
        // prepare encode frame.
        VTCompressionSessionPrepareToEncodeFrames(session)
    }
    
    private func disableSession() {
        if let session = self.session {
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }
        // formatDescription 必须置空，否则，再次推流的时候不会发送sps, pps，在某些服务器上不能播放。
        formatDescription = nil
    }
    
    func run() {
        self.configSession()
        self.enableSession()
    }
    
    func stop() {
        self.disableSession()
    }
    
    // for encoding raw image sample buffer.
    func encode(sampleBuffer: CMSampleBuffer) {
        guard let session: VTCompressionSessionRef = session else { return }
        
        let image = CMSampleBufferGetImageBuffer(sampleBuffer)
        guard let imageBuffer = image else { return }
        
        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let presentationDuration = CMSampleBufferGetDuration(sampleBuffer)
        
        var flags:VTEncodeInfoFlags = VTEncodeInfoFlags()
        // TODO: not sure the effect of each parameter
        VTCompressionSessionEncodeFrame(session, imageBuffer, presentationTimeStamp, presentationDuration, nil, nil, &flags)
    }
}
