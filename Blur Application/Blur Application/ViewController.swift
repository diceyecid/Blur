//
//  ViewController.swift
//  Blur Application
//
//  Created by Ross Shen on 2022-11-19.
//

import UIKit
import AVKit
import Vision
import MetalKit
import CoreImage

class ViewController: UIViewController
{
   /*---------- variables ----------*/
   
   
   // AVCapture variables
   private let captureSession = AVCaptureSession()
   private let captureDevice = AVCaptureDevice.default( for: .video )
//    private let previewLayer = AVCaptureVideoPreviewLayer()
   private let dataOutput = AVCaptureVideoDataOutput()
   private var captureResolution = CMVideoDimensions()
   
   // for drawing bounding box
//   private let overlayLayer = CALayer()
//   private var bboxTransform =  CGAffineTransform.identity
   
   // for face detection and analysis
   private var faceRequest: VNDetectFaceRectanglesRequest?
   private var faceObservations: [VNFaceObservation] = []
   private var genderModel: VNCoreMLModel?
   private var genderRequest: VNCoreMLRequest?
   private var genderObservations: [VNClassificationObservation] = []
   private var raceModel: VNCoreMLModel?
   private var raceRequest: VNCoreMLRequest?
   private var raceObservations: [VNClassificationObservation] = []
   
   // for threading
   private var inferencingCount = 0
   private let semaphore = DispatchSemaphore( value: 2 )
   
   // for metal GPU accelleration
   private let mtkView = MTKView()
   private let metalDevice = MTLCreateSystemDefaultDevice()
   private var metalCommandQueue: MTLCommandQueue!
   
   // for using filters
   private var context: CIContext!
   private var curImage: CIImage?
   private let scaleFilter = CIFilter( name: "CILanczosScaleTransform" )
   private let blurFilter = CIFilter( name: "CIGaussianBlur" )
   

   
   /*---------- life hook functions ----------*/
   
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      setupMetal()
      setupCoreImage()
      setupModels()
      setupCamera()
//      setupDrawingLayers()
   }
   
//   override func viewDidLayoutSubviews()
//   {
//      super.viewDidLayoutSubviews()
//      updateCameraOrientation()
//   }
   
//   override func viewWillTransition( to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator )
//   {
//      super.viewWillTransition( to: size, with: coordinator )
//
//      coordinator.animate( alongsideTransition: nil, completion:
//                              { [weak self] ( context ) in
//         DispatchQueue.main.async
//         {
//            self?.updateCameraOrientation()
//         }
//      } )
//   }
   
   
   /*---------- setup functions ----------*/
   
   
   // set up metal
   fileprivate func setupMetal()
   {
      // set up metal view
      mtkView.translatesAutoresizingMaskIntoConstraints = false
      mtkView.frame = view.frame
      mtkView.device = metalDevice
      
      // tell metal view to use explicit drawing
      mtkView.isPaused = true
      mtkView.enableSetNeedsDisplay = false
      
      // create a command queue to send instruction to GPU
      metalCommandQueue = metalDevice?.makeCommandQueue()
      
      // conform to our MTKView's delegate
      mtkView.delegate = self
      
      // let drawable texture be written
      mtkView.framebufferOnly = false
      
      // add to view
      view.addSubview( mtkView )
   }
   
   // set up core image
   fileprivate func setupCoreImage()
   {
      context = CIContext( mtlDevice: metalDevice!)
   }
   
   // set up ml models and vision requests
   fileprivate func setupModels()
   {
      // face dection
      self.faceRequest = VNDetectFaceRectanglesRequest( completionHandler: faceRequestDidComplete )
      
      // gender model
      if let genderModel = try? VNCoreMLModel( for: gender_model().model )
      {
         self.genderModel = genderModel
         self.genderRequest = VNCoreMLRequest( model: genderModel, completionHandler: genderRequestDidComplete )
         self.genderRequest?.imageCropAndScaleOption = .scaleFill
      }
      
      // race model
      if let raceModel = try? VNCoreMLModel( for: race_model().model )
      {
         self.raceModel = raceModel
         self.raceRequest = VNCoreMLRequest( model: raceModel, completionHandler: raceRequestDidComplete )
         self.raceRequest?.imageCropAndScaleOption = .scaleFill
      }
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
      //        previewLayer.session = captureSession
      //        view.layer.addSublayer( previewLayer )
      
      // set up data output
      dataOutput.setSampleBufferDelegate( self, queue: DispatchQueue( label: "videoQueue" ) )
      captureSession.addOutput( dataOutput )
   }
   
   // set up drawing layers
//   fileprivate func setupDrawingLayers()
//   {
//      // overlay layer
//      overlayLayer.name = "DetectionOverlay"
//      overlayLayer.masksToBounds = true
//      //        previewLayer.addSublayer( overlayLayer )
//      mtkView.layer.addSublayer( overlayLayer )
//   }
   
   
   /*---------- update functions ----------*/
   
   
   // disabled rotation, so this is currently not needed
   // update camera orientation based on UI orientation
//   fileprivate func updateCameraOrientation()
//   {
//      // base on device orientation,
//      // switch orientation of the preview layer and overlay layers, and
//      // update bounding box transform
//      // NOT WORKING: texture inside metal view is not rotating
//      switch UIDevice.current.orientation
//      {
//         // home button on top
//      case UIDeviceOrientation.portraitUpsideDown:
//         //                print( "portrait upside down" )
//         //                previewLayer.connection?.videoOrientation = .portraitUpsideDown
//
//         overlayLayer.bounds = CGRect( x: 0,
//                                       y: 0,
//                                       width: CGFloat( captureResolution.height ),
//                                       height: CGFloat( captureResolution.width ) )
//         bboxTransform = CGAffineTransform.identity
//            .scaledBy( x: 1, y: -1 )
//            .translatedBy( x: overlayLayer.bounds.width, y: 0 - overlayLayer.bounds.height )
//            .scaledBy( x: overlayLayer.bounds.width, y: overlayLayer.bounds.height )
//            .rotated( by: Double.pi / 2 )
//         break
//
//         // home button on right
//      case UIDeviceOrientation.landscapeLeft:
//         //                print( "landscape left" )
//         //                previewLayer.connection?.videoOrientation = .landscapeRight
//         overlayLayer.bounds = CGRect( x: 0,
//                                       y: 0,
//                                       width: CGFloat( captureResolution.width ),
//                                       height: CGFloat( captureResolution.height ) )
//         bboxTransform = CGAffineTransform.identity
//            .scaledBy( x: 1, y: -1 )
//            .translatedBy( x: 0, y: 0 - overlayLayer.bounds.height )
//            .scaledBy( x: overlayLayer.bounds.width, y: overlayLayer.bounds.height )
//         break
//
//         // home button on left
//      case UIDeviceOrientation.landscapeRight:
//         //                print( "landscape right" )
//         //                previewLayer.connection?.videoOrientation = .landscapeLeft
//         overlayLayer.bounds = CGRect( x: 0,
//                                       y: 0,
//                                       width: CGFloat( captureResolution.width ),
//                                       height: CGFloat( captureResolution.height ) )
//         bboxTransform = CGAffineTransform.identity
//            .scaledBy( x: -1, y: 1 )
//            .translatedBy( x: 0 - overlayLayer.bounds.width, y: 0 )
//            .scaledBy( x: overlayLayer.bounds.width, y: overlayLayer.bounds.height )
//         break
//
//         // home button on bottom
//      case UIDeviceOrientation.portrait:
//         //                print( "portrait" )
//         //                previewLayer.connection?.videoOrientation = .portrait
//         overlayLayer.bounds = CGRect( x: 0,
//                                       y: 0,
//                                       width: CGFloat( captureResolution.height ),
//                                       height: CGFloat( captureResolution.width ) )
//         bboxTransform = CGAffineTransform.identity
//            .scaledBy( x: -1, y: 1 )
//            .scaledBy( x: overlayLayer.bounds.width, y: overlayLayer.bounds.height )
//            .rotated( by: Double.pi / 2 )
//         break
//
//      default:
//         break
//      }
//
//      // maximize preview layer size
//      //        previewLayer.videoGravity = .resizeAspectFill
//      //        previewLayer.frame = view.layer.bounds
//
//      // update metal view
//      mtkView.frame = view.frame
//
//      // reposition overlay layer
//      //        overlayLayer.anchorPoint = previewLayer.anchorPoint
//      //        overlayLayer.position = previewLayer.position
//      overlayLayer.anchorPoint = mtkView.layer.anchorPoint
//      overlayLayer.position = mtkView.layer.position
//   }
}

// vision request completion handler extension
extension ViewController
{
   func genderRequestDidComplete( request: VNRequest, error: Error? )
   {
//      print( "start completing gender classification" )
      
      // error
      if error != nil
      {
         print( "Failed to detect gender: \( String( describing: error ) )." )
         return
      }
      
      // get results from gender detection
      if let results = request.results as? [VNClassificationObservation]
      {
         DispatchQueue.global().async
         {
            let prediction = results.max{ a, b in a.confidence < b.confidence }
            self.genderObservations.append( prediction! )
            self.inferencingCount -= 1
            self.semaphore.signal()
         }
      }
      else
      {
         self.inferencingCount -= 1
         self.semaphore.signal()
      }
      
//      print( "finished completing gender classification" )
   }
   
   func raceRequestDidComplete( request: VNRequest, error: Error? )
   {
//      print( "start completing race classification" )
      
      // error
      if error != nil
      {
         print( "Failed to detect race: \( String( describing: error ) )." )
         return
      }
      
      // get results from race detection
      if let results = request.results as? [VNClassificationObservation]
      {
         DispatchQueue.global().async
         {
            let prediction = results.max{ a, b in a.confidence < b.confidence }
            self.raceObservations.append( prediction! )
            self.inferencingCount -= 1
            self.semaphore.signal()
         }
      }
      else
      {
         self.inferencingCount -= 1
         self.semaphore.signal()
      }
      
//      print( "finished completing race classification" )
   }
   
   func faceRequestDidComplete( req: VNRequest, err: Error? )
   {
//      print( "start completing face detection" )
      
      // error
      if err != nil
      {
         print( "Failed to detect faces: \( String( describing: err ) )." )
         return
      }
      
      // refresh observations from last frame
      self.genderObservations = []
      self.raceObservations = []
      
      // get results from face detection
      guard let results = req.results as? [VNFaceObservation] else { return }
      self.faceObservations = results
      
      // face analysis
      for obs in self.faceObservations
      {
         // preprocess image to get face only
         let bbox = VNImageRectForNormalizedRect( obs.boundingBox,
                                                  Int( self.captureResolution.width ),
                                                  Int( self.captureResolution.height ) )
         let bboxImage = self.curImage?.cropped( to: bbox )
         
         // analyze face
         let handler = VNImageRequestHandler( ciImage: bboxImage!, options: [:] )
         var requests : [VNCoreMLRequest] = []
         requests.append( self.genderRequest! )
         requests.append( self.raceRequest! )
         
         do
         {
            self.semaphore.wait()
            self.semaphore.wait()
            self.inferencingCount += 2
//            print( "start performing race and gender classification" )
            try handler.perform( requests )
//            print( "finished performing race and gender classification" )
         }
         catch let reqErr
         {
            print( "Failed to perform request:", reqErr )
         }
      }
      
      self.inferencingCount -= 1
//      print( "finished completing face detection" )
      
      // draw bounding boxes
      //            DispatchQueue.main.async
      //            {
      //                // clear all bounding boxes from previous frame
      //                self.overlayLayer.sublayers?.forEach{ layer in layer.removeFromSuperlayer() }
      //
      //                for obs in results
      //                {
      //                    // add a bounding box to each observed face
      //                    let layer = CAShapeLayer()
      //                    layer.frame = obs.boundingBox.applying( self.bboxTransform )
      //                    layer.borderColor = UIColor.green.withAlphaComponent( 0.7 ).cgColor
      //                    layer.borderWidth = 5
      //                    self.overlayLayer.addSublayer( layer )
      //                }
      //            }
   }
}

// video output delegation extension
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate
{
   // process each frame
   func captureOutput( _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection )
   {
//      print( inferencingCount )
      if( inferencingCount == 0 )
      {
         // try an get a CVImageBuffer out of the sample buffer
         guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer( sampleBuffer ) else { return }
         //        print( CVPixelBufferGetPixelFormatType( pixelBuffer ) )
         
         // get a CIImage ourt of the CVImageBuffer
         self.curImage = CIImage( cvPixelBuffer: pixelBuffer )
         
         DispatchQueue.main.async
         {
            // start drawing metal view
            self.mtkView.draw()
         }
         
         // handle image request
         DispatchQueue.global().async
         {
            let handler = VNImageRequestHandler( cvPixelBuffer: pixelBuffer, options: [:] )
            do
            {
//               print( "start performing face detection" )
               self.inferencingCount += 1
               try handler.perform( [ self.faceRequest! ] )
//               print( "finished performing face detection" )
            }
            catch let reqErr
            {
               print( "Failed to perform request:", reqErr )
            }
         }
      }
   }
}

// metal renderer delegation
extension ViewController: MTKViewDelegate
{
   // drawable size changed
   func mtkView( _ view: MTKView, drawableSizeWillChange size: CGSize )
   {
      
   }
   
   // render to screen
   func draw( in view: MTKView )
   {
      // create command buffer for context to use to encode it's rendering instructions to GPU
      guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else { return }
      
      // make sure there is actually an image
      guard let image = curImage else { return }
      
      // make sure the current drawable object for this metal view is available
      guard let curDrawable = view.currentDrawable else { return }
      
      // variables
      let imageWidth = image.extent.width
      let imageHeight = image.extent.height
      let drawableWidth = view.drawableSize.width
      let drawableHeight = view.drawableSize.height
      var filteredImage = image
      
      // blur image at face observation bounding boxes
      var blurredImage = filteredImage
      for ( i, ( race, gender ) ) in zip( raceObservations, genderObservations ).enumerated()
      {
         let face = faceObservations[i]
         
//         print( race.identifier + " " + gender.identifier )
//         print( String( race.confidence ) + " " + String( gender.confidence ) )
         
         // blur the face if it's not a white man
         if( !( gender.identifier == "Man" && race.identifier == "white" ) )
         {
            let bbox = VNImageRectForNormalizedRect( face.boundingBox,
                                                     Int( captureResolution.width ),
                                                     Int( captureResolution.height ) )
            let bboxImage = blurredImage.cropped( to: bbox )
            blurFilter?.setValue( bboxImage, forKey: kCIInputImageKey )
            blurFilter?.setValue( 20.0, forKey: kCIInputRadiusKey )
            blurredImage = ( blurFilter?.outputImage?.composited( over: blurredImage ) )!
         }
      }
      filteredImage = blurredImage
      
      // resize image to fit screen
      let scaledImage = filteredImage
      let scaleX = drawableWidth / imageWidth
      let scaleY = drawableHeight / imageHeight
      let scaleFactor = scaleX > scaleY ? scaleX : scaleY
      scaleFilter?.setValue( scaledImage, forKey: kCIInputImageKey )
      scaleFilter?.setValue( scaleFactor, forKey: kCIInputScaleKey )
      filteredImage = ( scaleFilter?.outputImage )!
      
      // calcuate offset to place the image in center of screen
      let xOffsetFromLeft = ( drawableWidth - filteredImage.extent.width ) / 2
      let yOffsetFromBottom = ( drawableHeight - filteredImage.extent.height ) / 2
      
      // render into the metal texture
      self.context.render( filteredImage,
                           to: curDrawable.texture,
                           commandBuffer: commandBuffer,
                           bounds: CGRect( origin: CGPoint( x: -xOffsetFromLeft, y: -yOffsetFromBottom ), size: view.drawableSize ),
                           colorSpace: CGColorSpaceCreateDeviceRGB() )
      
      // register where to draw the instructions in the command buffer
      commandBuffer.present( curDrawable )
      
      // commit the command to the queue so it executes
      commandBuffer.commit()
   }
}
