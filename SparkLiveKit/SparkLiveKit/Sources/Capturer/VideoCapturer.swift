//
//  VideoIOComponent.swift
//  VTToolbox_swift
//
//  Created by gezhaoyou on 16/7/7.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

final class VideoCapturer: NSObject {
    private let capturerQueue: dispatch_queue_t = dispatch_queue_create("VideoCapturer", DISPATCH_QUEUE_SERIAL)
    static let supportedSettings:[String] = [
        "devicePosition",
        "fps",
        "sessionPreset",
        "continuousAutofocus",
        "continuousExposure",
        ]
    // device positon: front camera and back camera
    var devicePosition: AVCaptureDevicePosition = .Back {
        didSet {
            if devicePosition == oldValue {
                return
            }
            dispatch_async(capturerQueue) {
                self.configCaptureInput()
                self.configVideoOrientation()
                // self.configVideoFps()
            }
        }
    }
    // video picture orientation.
    var videoOrientation: AVCaptureVideoOrientation = .Portrait {
        didSet {
            if videoOrientation == oldValue {
                return
            }
            self.configVideoOrientation()
        }
    }
    
    // 帧率
    var fps: Float64 = 25 {
        didSet {
            if fps == oldValue {
                return
            }
            dispatch_async(capturerQueue) {
                self.configVideoFps()
            }
        }
    }
    
    var sessionPreset: String = AVCaptureSessionPreset1280x720 {
        didSet {
            guard sessionPreset != oldValue else {
                return
            }
            dispatch_async(capturerQueue) {
                self.configSession()
            }
        }
    }
    
    var continuousExposure: Bool = false {
        didSet {
            guard continuousExposure != oldValue else {
                return
            }
            dispatch_async(capturerQueue) {
                self.configExposure()
            }
        }
    }
    
    // 自动对焦
    var continuousAutofocus: Bool = false {
        didSet {
            guard continuousAutofocus != oldValue else {
                return
            }
            dispatch_async(capturerQueue) {
                self.configAutofocus()
            }
        }
    }
    
    var videoPreviewView: VideoPreviewView = VideoPreviewView()
    var session: AVCaptureSession!

    private var captureOutput: AVCaptureVideoDataOutput!
    private var captureInput: AVCaptureDeviceInput?

    private var outputHandler: OutputHandler?
    
    // get appropriate fps value
    private func getActualFPS(fps:Float64, device:AVCaptureDevice) -> (fps:Float64, duration:CMTime)? {
        // @see https://www.objccn.io/issue-23-1/
        var durations:[CMTime] = []
        var frameRates:[Float64] = []
        
        for object:AnyObject in device.activeFormat.videoSupportedFrameRateRanges {
            guard let range:AVFrameRateRange = object as? AVFrameRateRange else {
                continue
            }
            if (range.minFrameRate == range.maxFrameRate) {
                durations.append(range.minFrameDuration)
                frameRates.append(range.maxFrameRate)
                continue
            }
            // 说明 fps 在支持的范围之内， 返回
            if (range.minFrameRate <= fps && fps <= range.maxFrameRate) {
                return (fps, CMTimeMake(100, Int32(100 * fps)))
            }
            
            // 若 fps不在支持的范围之内，则 get到支持的最大或者 最小的 fps，并返回（这段代码写的很漂亮，zhaoyou）
            let actualFPS:Float64 = max(range.minFrameRate, min(range.maxFrameRate, fps))
            return (actualFPS, CMTimeMake(100, Int32(100 * actualFPS)))
        }
        
        var diff:[Float64] = []
        for frameRate in frameRates {
            diff.append(abs(frameRate - fps))
        }
        if let minElement:Float64 = diff.minElement() {
            for i in 0..<diff.count {
                if (diff[i] == minElement) {
                    return (frameRates[i], durations[i])
                }
            }
        }
        return nil
    }
    
    // get capturer device with position
    private func deviceWithPosition(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        for device in AVCaptureDevice.devices() {
            guard let device:AVCaptureDevice = device as? AVCaptureDevice else {
                continue
            }
            
            if (device.hasMediaType(AVMediaTypeVideo) && device.position == position) {
                return device
            }
        }
        return nil
    }
    
    private func configVideoOrientation() {
        if let connection:AVCaptureConnection = videoPreviewView.layer.valueForKey("connection") as? AVCaptureConnection {
            if (connection.supportsVideoOrientation) {
                connection.videoOrientation = videoOrientation
            }
        }
        
        guard let output = captureOutput else {
            return
        }
        
        if let connection:AVCaptureConnection = output.connectionWithMediaType(AVMediaTypeVideo) {
            if connection.supportsVideoOrientation {
                connection.videoOrientation = videoOrientation
            }
        }
    }
    
    private func configAutofocus() {
        let focusMode:AVCaptureFocusMode = continuousAutofocus ? .ContinuousAutoFocus : .AutoFocus
        guard let device:AVCaptureDevice = self.captureInput?.device
            where device.isFocusModeSupported(focusMode) else {
                // logger.warning("focusMode(\(focusMode.rawValue)) is not supported")
                return
        }
        do {
            try device.lockForConfiguration()
            device.focusMode = focusMode
            device.unlockForConfiguration()
        }
        catch let error as NSError {
            //logger.error("while locking device for autofocus: \(error)")
        }

    }
    
    private func configExposure() {
        let exposureMode:AVCaptureExposureMode = continuousExposure ? .ContinuousAutoExposure : .AutoExpose
        guard let device:AVCaptureDevice = captureInput?.device
            where device.isExposureModeSupported(exposureMode) else {
                // logger.warning("exposureMode(\(exposureMode.rawValue)) is not supported")
                return
        }
        do {
            try device.lockForConfiguration()
            device.exposureMode = exposureMode
            device.unlockForConfiguration()
        } catch let error as NSError {
            // logger.error("while locking device for autoexpose: \(error)")
        }

    }
    
    private func configVideoFps() {
        guard let device: AVCaptureDevice = self.captureInput?.device,
            data = self.getActualFPS(self.fps, device: device) else {
                return
        }
        // update fps to true value.
        self.fps = data.fps
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = data.duration
            device.activeVideoMaxFrameDuration = data.duration
            device.unlockForConfiguration()
        } catch let error as NSError {
            // log error.
        }
    }
    
    private func configVideoPreview() {
        // TODO: not very good, do better sometime.
        videoPreviewView.session = session
    }
    
    private func configCaptureOutput() {
        guard let session = self.session else {
            return
        }
        
        if captureOutput != nil {
            session.removeOutput(captureOutput)
        }
        captureOutput = AVCaptureVideoDataOutput()
        captureOutput.alwaysDiscardsLateVideoFrames = true;
        
        // 像素格式类型, 不是太懂
        // also can set kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        captureOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString):NSNumber(unsignedInt: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        // init output & input
        captureOutput.setSampleBufferDelegate(self, queue: capturerQueue)
        if session.canAddOutput(captureOutput) {
            session.addOutput(captureOutput)
        }
        
        for connection in captureOutput.connections {
            guard let connection:AVCaptureConnection = connection as? AVCaptureConnection else {
                continue
            }
            
            if (connection.supportsVideoOrientation) {
                connection.videoOrientation = videoOrientation
            }
        }
    }
    
    private func configCaptureInput() {
        guard let device: AVCaptureDevice = deviceWithPosition(self.devicePosition) else {
            return
        }
        guard let session = self.session else {
            return
        }
        do {
            if captureInput != nil {
                session.removeInput(captureInput)
            }
            captureInput = try AVCaptureDeviceInput(device: device)
            // add input & output
            if session.canAddInput(captureInput) {
                session.addInput(captureInput)
            }
           
        } catch let error as NSError {
            print(error)
        }
    }
    
    private func configSession() {
        // config session
        guard let session = session else {
            return
        }
        session.beginConfiguration()
        // 相机捕获视频质量（宽 * 高）
        if session.canSetSessionPreset(sessionPreset) {
            session.sessionPreset = sessionPreset
        }
        session.commitConfiguration()
    }

    //
    func attachCamera() {
        self.configCaptureOutput()
        self.configCaptureInput()
        self.configVideoFps()
        self.configSession()
        self.configVideoOrientation()
        self.configVideoPreview()
    }

    /// CMSampleBuffer data call back
    func output(outputHandler: OutputHandler) {
        // the real call back must be on didOutputSampleBuffer
        self.outputHandler = outputHandler
    }
}

extension VideoCapturer {
    typealias OutputHandler = (sampleBuffer: CMSampleBuffer) -> Void
}

extension VideoCapturer: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(captureOutput:AVCaptureOutput!, didOutputSampleBuffer sampleBuffer:CMSampleBuffer!, fromConnection connection:AVCaptureConnection!) {
        self.outputHandler?(sampleBuffer: sampleBuffer)
    }
}
