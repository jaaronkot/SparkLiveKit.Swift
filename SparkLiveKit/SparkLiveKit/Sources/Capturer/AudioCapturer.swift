//
//  AudioCapturer.swift
//  SparkShow
//
//  Created by gezhaoyou on 16/8/3.
//  Copyright © 2016年 gezhaoyou. All rights reserved.
//

import Foundation
import AVFoundation

final class AudioCapturer: NSObject {
    private let capturerQueue: dispatch_queue_t = dispatch_queue_create("AudioCapturer", DISPATCH_QUEUE_SERIAL)
    
    var session: AVCaptureSession!
    var captureOutput: AVCaptureAudioDataOutput!
    var captureInput: AVCaptureDeviceInput!
    
    private var outputHandler: OutputHandler?

    private func configCapturerOutput() {
        guard let session = session else {
            return
        }
        if captureOutput != nil {
            captureOutput.setSampleBufferDelegate(nil, queue: nil)
            session.removeOutput(captureOutput)
        }
        captureOutput = AVCaptureAudioDataOutput()
        captureOutput.setSampleBufferDelegate(self, queue: capturerQueue)
        if session.canAddOutput(captureOutput) {
            session.addOutput(captureOutput)
        }
    }
    
    private func configCapturerInput() {
        guard let device: AVCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio) else {
            // log error!
            return
        }
        
        guard let session = self.session else {
            return
        }
        do {
            captureInput = try AVCaptureDeviceInput(device: device)
            session.automaticallyConfiguresApplicationAudioSession =  true
            if session.canAddInput(captureInput) {
                session.addInput(captureInput)
            }
        } catch let error as NSError {
            // logger.error("\(error)")
        }
    }
    
    func attachMicrophone() {
        self.configCapturerOutput()
        self.configCapturerInput()
    }
    
    func output(outputHandler: OutputHandler) {
        self.outputHandler = outputHandler
    }
}

// raw audio data.
extension AudioCapturer: AVCaptureAudioDataOutputSampleBufferDelegate {
    typealias OutputHandler = (sampleBuffer: CMSampleBuffer) -> Void
    
    func captureOutput(captureOutput:AVCaptureOutput!, didOutputSampleBuffer sampleBuffer:CMSampleBuffer!, fromConnection connection:AVCaptureConnection!) {
        
        self.outputHandler?(sampleBuffer: sampleBuffer)
    }
}
