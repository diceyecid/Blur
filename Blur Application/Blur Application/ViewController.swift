//
//  ViewController.swift
//  Blur Application
//
//  Created by Ross Shen on 2022-11-19.
//

import UIKit
import AVKit
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate
{
    // AVCapture variables
    private let captureSession = AVCaptureSession()
    private let captureDevice = AVCaptureDevice.default( for: .video )
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let dataOutput = AVCaptureVideoDataOutput()
    private var captureResolution = CMVideoDimensions()
    
    // for drawing bounding box
    private let overlayLayer = CALayer()
    private var bboxTransform =  CGAffineTransform.identity
    
    // update camera orientation based on UI orientation
    fileprivate func updateCameraOrientation()
    {
        // base on device orientation,
        // switch orientation of the preview layer and overlay layers, and
        // update bounding box transform
        switch UIDevice.current.orientation
        {
            // home button on top
            case UIDeviceOrientation.portraitUpsideDown:
                print( "portrait upside down" )
                previewLayer.connection?.videoOrientation = .portraitUpsideDown
                overlayLayer.bounds = CGRect( x: 0,
                                              y: 0,
                                              width: CGFloat( captureResolution.height ),
                                              height: CGFloat( captureResolution.width ) )
                bboxTransform = CGAffineTransform.identity
                                    .scaledBy( x: 1, y: -1 )
                                    .translatedBy( x: overlayLayer.bounds.width, y: 0 - overlayLayer.bounds.height )
                                    .scaledBy( x: overlayLayer.bounds.width, y: overlayLayer.bounds.height )
                                    .rotated( by: Double.pi / 2 )
                break
            
            // home button on right
            case UIDeviceOrientation.landscapeLeft:
                print( "landscape left" )
                previewLayer.connection?.videoOrientation = .landscapeRight
                overlayLayer.bounds = CGRect( x: 0,
                                              y: 0,
                                              width: CGFloat( captureResolution.width ),
                                              height: CGFloat( captureResolution.height ) )
                bboxTransform = CGAffineTransform.identity
                                    .scaledBy( x: 1, y: -1 )
                                    .translatedBy( x: 0, y: 0 - overlayLayer.bounds.height )
                                    .scaledBy( x: overlayLayer.bounds.width, y: overlayLayer.bounds.height )
                break
            
            // home button on left
            case UIDeviceOrientation.landscapeRight:
                print( "landscape right" )
                previewLayer.connection?.videoOrientation = .landscapeLeft
                overlayLayer.bounds = CGRect( x: 0,
                                              y: 0,
                                              width: CGFloat( captureResolution.width ),
                                              height: CGFloat( captureResolution.height ) )
                bboxTransform = CGAffineTransform.identity
                                    .scaledBy( x: -1, y: 1 )
                                    .translatedBy( x: 0 - overlayLayer.bounds.width, y: 0 )
                                    .scaledBy( x: overlayLayer.bounds.width, y: overlayLayer.bounds.height )
                break
                
            // home button on bottom
            case UIDeviceOrientation.portrait:
                print( "portrait" )
                previewLayer.connection?.videoOrientation = .portrait
                overlayLayer.bounds = CGRect( x: 0,
                                              y: 0,
                                              width: CGFloat( captureResolution.height ),
                                              height: CGFloat( captureResolution.width ) )
                bboxTransform = CGAffineTransform.identity
                                    .scaledBy( x: -1, y: 1 )
                                    .scaledBy( x: overlayLayer.bounds.width, y: overlayLayer.bounds.height )
                                    .rotated( by: Double.pi / 2 )
                break
            
            default:
                break
        }
        
        // maximize preview layer size
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        
        // reposition overlay layer
        overlayLayer.anchorPoint = previewLayer.anchorPoint
        overlayLayer.position = previewLayer.position
    }
    
    // set up AVCapture session
    fileprivate func setupCamera()
    {
        // set up capture session
        captureSession.sessionPreset = .high
        guard let device = captureDevice else { return }
        guard let input = try? AVCaptureDeviceInput( device: device ) else { return }
        captureSession.addInput( input )
        captureSession.startRunning()
        captureResolution = captureDevice?.activeFormat.formatDescription.dimensions ?? CMVideoDimensions()
        print( captureResolution )
        
        // set up privew layer
        previewLayer.session = captureSession
        view.layer.addSublayer( previewLayer )
        
        // set up data output
        dataOutput.setSampleBufferDelegate( self, queue: DispatchQueue( label: "videoQueue" ) )
        captureSession.addOutput( dataOutput )
    }
    
    // set up drawing layers
    fileprivate func setupDrawingLayers()
    {
        // overlay layer
        overlayLayer.name = "DetectionOverlay"
        overlayLayer.masksToBounds = true
        previewLayer.addSublayer( overlayLayer )
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        setupCamera()
        setupDrawingLayers()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        updateCameraOrientation()
    }
    
    override func viewWillTransition( to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator )
    {
        super.viewWillTransition( to: size, with: coordinator )
        
        coordinator.animate( alongsideTransition: nil, completion:
        { [weak self] ( context ) in
            DispatchQueue.main.async
            {
                self?.updateCameraOrientation()
            }
        } )
    }
    
    // process each frame
    func captureOutput( _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection )
    {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer( sampleBuffer ) else { return }
        
        let faceDetectionReq = VNDetectFaceRectanglesRequest
        { ( req, err ) in
            
            // error
            if err != nil
            {
                print( "Failed to detect faces: \( String( describing: err ) )." )
                return
            }
            
            // get results from face detection
            guard let results = req.results as? [VNFaceObservation] else { return }
            
            // add observations to the tracking list
            DispatchQueue.main.async
            {
                // clear all bounding boxes from previous frame
                self.overlayLayer.sublayers?.forEach{ layer in layer.removeFromSuperlayer() }
                
                for obs in results
                {
                    let layer = CAShapeLayer()
                    layer.frame = obs.boundingBox.applying( self.bboxTransform )
                    layer.borderColor = UIColor.green.withAlphaComponent( 0.7 ).cgColor
                    layer.borderWidth = 5
                    layer.shadowOpacity = 0.7
                    layer.shadowRadius = 5
                    self.overlayLayer.addSublayer( layer )
//                    let faceTrackingReq = VNTrackObjectRequest( detectedObjectObservation: obs )
                }
            }
        }
        
        DispatchQueue.global( qos: .userInteractive ).async
        {
            let handler = VNImageRequestHandler( cvPixelBuffer: pixelBuffer, options: [:] )
            
            do
            {
                try handler.perform([ faceDetectionReq ])
            }
            catch let reqErr
            {
                print("Failed to perform request:", reqErr)
            }
        }
    }
}
