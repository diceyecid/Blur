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
    private let captureSession = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let dataOutput = AVCaptureVideoDataOutput()
    
    fileprivate func updateCameraOrientation()
    {
        // switch orientation of the preview layer based on device rotation
        switch UIDevice.current.orientation
        {
            // home button on top
            case UIDeviceOrientation.portraitUpsideDown:
                previewLayer.connection?.videoOrientation = .portraitUpsideDown
                break
            
            // home button on right
            case UIDeviceOrientation.landscapeLeft:
                previewLayer.connection?.videoOrientation = .landscapeRight
                break
            
            // home button on left
            case UIDeviceOrientation.landscapeRight:
                previewLayer.connection?.videoOrientation = .landscapeLeft
                break
                
            // home button on bottom
            case UIDeviceOrientation.portrait:
                previewLayer.connection?.videoOrientation = .portrait
                break
            
            default:
                break
        }
        
        // maximize preview layer size
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
    }
    
    fileprivate func setupCamera()
    {
        // set up capture session
        captureSession.sessionPreset = .high
        guard let captureDevice = AVCaptureDevice.default( for: .video ) else { return }
        guard let input = try? AVCaptureDeviceInput( device: captureDevice ) else { return }
        captureSession.addInput( input )
        captureSession.startRunning()
        
        // set up privew layer
        previewLayer.session = captureSession
        view.layer.addSublayer( previewLayer )
        
        // set up data output
        dataOutput.setSampleBufferDelegate( self, queue: DispatchQueue( label: "videoQueue" ) )
        captureSession.addOutput( dataOutput )
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        setupCamera()
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
    
    func captureOutput( _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection )
    {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer( sampleBuffer ) else { return }
        
        let request = VNDetectFaceRectanglesRequest
        { ( req, err ) in
            
            // error
            if err != nil
            {
                print( "Failed to detect faces: \( String( describing: err ) )." )
                return
            }
            
            // get results from face detection
            guard let faceDectionReq = req as? VNDetectFaceRectanglesRequest,
                  let results = faceDectionReq.results else { return }
            
            // add observations to the tracking list
            DispatchQueue.main.async
            {
                for obs in results
                {
                    print( obs )
//                    let faceTrackingReq = VNTrackObjectRequest( detectedObjectObservation: obs )
                }
            }
        }
        
        DispatchQueue.global( qos: .userInteractive ).async
        {
            let handler = VNImageRequestHandler( cvPixelBuffer: pixelBuffer, options: [:] )
            
            do
            {
                try handler.perform([request])
            }
            catch let reqErr
            {
                print("Failed to perform request:", reqErr)
            }
        }
    }
}
