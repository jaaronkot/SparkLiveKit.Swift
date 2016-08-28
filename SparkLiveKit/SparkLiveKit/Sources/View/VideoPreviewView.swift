//
//  File.swift
//  SparkShow
//
//  Created by gezhaoyou on 16/8/4.
//

import Foundation
import AVFoundation
import UIKit

public class VideoPreviewView: UIView {
    required override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.blackColor()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        backgroundColor = UIColor.blackColor()
    }
    
    override public class func layerClass() -> AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var session: AVCaptureSession {
        get {
            let previewLayer: AVCaptureVideoPreviewLayer = self.layer as! AVCaptureVideoPreviewLayer
            return previewLayer.session
        }
        
        set{
            let previewLayer: AVCaptureVideoPreviewLayer = self.layer as! AVCaptureVideoPreviewLayer
            previewLayer.session = newValue
            // preview full screen
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        }
    }
}
