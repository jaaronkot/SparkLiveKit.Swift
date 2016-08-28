//
//  Controller.swift
//  SparkShow
//
//  Created by gezhaoyou on 16/8/3.
//

import Foundation
import AVFoundation
import UIKit

protocol BroadcastControllerf {
    //
}

public class SparkPulishClient: NSObject {
    private let pulishClientQueue: dispatch_queue_t = dispatch_queue_create(
        "BVCPulishClient", DISPATCH_QUEUE_SERIAL
    )
    private var isPublishReady = false
    
    private var videoOrientation: AVCaptureVideoOrientation = .Portrait {
        didSet {
            if videoOrientation == oldValue {
                return
            }
            videoCapturer.videoOrientation = videoOrientation
            videoEncoder.videoOrientation = videoOrientation
        }
    }

    // capturer
    private let videoCapturer = VideoCapturer()
    private let audioCapturer = AudioCapturer()
    private let captureSession = AVCaptureSession()
    
    // ecncoder
    private let videoEncoder = AVCEncoder()
    private let audioEncdoer = AACEncoder()
    
    // muxer
    private var rtmpMuxer = RtmpMuxer()
    
    // rtmp
    private var rtmpPublisher = RtmpPublishClient()
    
    public var videoPreviewView: VideoPreviewView {
        return videoCapturer.videoPreviewView
    }
    
    // MARK: Video Capture Setting
    public var videoCapturerSettings:[String: AnyObject] {
        get {return videoCapturer.dictionaryWithValuesForKeys(VideoCapturer.supportedSettings)}
        set { videoCapturer.setValuesForKeysWithDictionary(newValue) }
    }
    
    // MARK: Video Encoding Setting
    public var videoEncoderSettings:[String: AnyObject] {
        get { return videoEncoder.dictionaryWithValuesForKeys(AVCEncoder.supportedSettingsKeys) }
        set { videoEncoder.setValuesForKeysWithDictionary(newValue) }
    }
    
    // MARK: Audio Encoding Setting
    public var audioEncodingSettings: [String: AnyObject] {
        get { return audioEncdoer.dictionaryWithValuesForKeys(AACEncoder.supportedSettingsKeys) }
        set { audioEncdoer.setValuesForKeysWithDictionary(newValue)}
    }
    
    // MARK: Camera Positioin
    public var devicePosition: AVCaptureDevicePosition{
        get { return videoCapturer.devicePosition }
        set { videoCapturer.devicePosition = newValue }
    }

    public override init() {
        super.init()
        self.rtmpSetting()
        self.capturerSetting()
        self.encodeSetting()
    }
    
//    private init(rtmpUrl: String) {
//        super.init()
//        self.rtmpPublisher = RtmpPublishClient(rtmpUrl: rtmpUrl)
//        self.Init()
//    }
    
    public func startPublish(ToUrl rtmpUrl: String) {
        if isPublishReady {
            return
        }
        dispatch_async(pulishClientQueue) {
            self.captureSession.startRunning()
            
            self.rtmpPublisher.setMediaMetaData(self.audioEncdoer.metaData)
            self.rtmpPublisher.setMediaMetaData(self.videoEncoder.metaData)
            
            self.rtmpPublisher.connect(rtmpUrl)

            self.videoEncoder.run()
            self.audioEncdoer.run()
        }
    }
    
    private func rtmpSetting() {
        self.rtmpPublisher.delegate = self
        self.rtmpMuxer.delegate = self
    }
    
    private func capturerSetting() {
        self.listenOrientationDidChangeNotification()
        // audio
        self.audioCapturer.session = self.captureSession
        self.audioCapturer.output { (sampleBuffer) in
            self.handleAudioCaptureBuffer(sampleBuffer)
        }
        self.audioCapturer.attachMicrophone()
        
        //video
        self.videoCapturer.session = self.captureSession
        self.videoCapturer.output { (sampleBUffer) in
            self.handleVideoCaptureBuffer(sampleBUffer)
        }
        self.videoCapturer.attachCamera()
    }
    
    private func encodeSetting() {
        // encode setting
        self.audioEncdoer.delegate = self
        self.videoEncoder.delegate = self
    }
    
    public func stop() {
        guard isPublishReady else {
            return
        }
        dispatch_async(pulishClientQueue) {
            self.captureSession.stopRunning()
            self.videoEncoder.stop()
            self.audioEncdoer.stop()
            self.rtmpPublisher.stop()
            self.isPublishReady = false
        }
    }
    
    deinit {
        
    }
    
    private func handleAudioCaptureBuffer(sampleBuffer: CMSampleBuffer) {
        guard isPublishReady else {
            return
        }
        audioEncdoer.encode(sampleBuffer)
    }
    
    private func handleVideoCaptureBuffer(sampleBuffer: CMSampleBuffer) {
        guard isPublishReady else {
            return
        }
        videoEncoder.encode(sampleBuffer)
    }
}

extension SparkPulishClient: RtmpPublisherDelegate {
    func onPublishStreamDone() {
        isPublishReady = true
    }
}

extension SparkPulishClient: AVCEncoderDelegate {
    func onGetAVCFormatDescription(formatDescription: CMFormatDescriptionRef?) {
        self.rtmpMuxer.muxAVCFormatDescription(formatDescription)
    }
    
    func onGetAVCSampleBuffer(sampleBuffer: CMSampleBuffer) {
        self.rtmpMuxer.muxAVCSampleBuffer(sampleBuffer)
    }
}

extension SparkPulishClient: AACEncoderDelegate {
    func onGetAACFormatDescription(formatDescription: CMFormatDescriptionRef?) {
        self.rtmpMuxer.muxAACFormatDescription(formatDescription)
    }
    
    func onGetAACSampleBuffer(sampleBuffer: CMSampleBuffer?) {
        //sampleBuffer
        self.rtmpMuxer.muxAACSampleBuffer(sampleBuffer)
    }
}

extension SparkPulishClient: RtmpMuxerDelegate {
    func sampleOutput(audio buffer:NSData, timestamp:Double) {
        var payload = [UInt8](count: buffer.length, repeatedValue: 0x00)
        buffer.getBytes(&payload, length: payload.count)
        rtmpPublisher.publishAudio(payload, timestamp: UInt32(timestamp))
    }
    
    func sampleOutput(video buffer:NSData, timestamp:Double) {
        var payload = [UInt8](count: buffer.length, repeatedValue: 0x00)
        buffer.getBytes(&payload, length: payload.count)
        rtmpPublisher.publishVideo(payload, timestamp: UInt32(timestamp))
    }
}

// MARK: Listen device orientation.
extension SparkPulishClient {
    private func listenOrientationDidChangeNotification() {
        let center: NSNotificationCenter = NSNotificationCenter.defaultCenter()
        center.addObserver(self, selector: #selector(SparkPulishClient.onOrientationChanged(_:)), name: UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    @objc private func onOrientationChanged(notification: NSNotification) {
        var deviceOrientation: UIDeviceOrientation = .Unknown
        if let device: UIDevice = notification.object as? UIDevice {
            deviceOrientation = device.orientation
        }
        
        if let orientation: AVCaptureVideoOrientation = getAVCaptureVideoOrientation(deviceOrientation) {
            if self.videoOrientation != orientation {
                self.videoOrientation = orientation
            }
        }
    }
    
    private func getAVCaptureVideoOrientation(orientation:UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch orientation {
        case .Portrait:
            return .Portrait
        case .PortraitUpsideDown:
            return .PortraitUpsideDown
        case .LandscapeLeft:
            return .LandscapeRight
        case .LandscapeRight:
            return .LandscapeLeft
        default:
            return nil
        }
    }
}
