//
//  Util.swift
//  Blur
//
//  Created by Ross Shen on 2022-11-23.
//

import Foundation
import Accelerate

class Util
{
    // initilize a CVPixelBuffer
    static func createCVPixelBuffer( width : Int, height : Int ) -> CVPixelBuffer?
    {
        var pixelBuffer : CVPixelBuffer? = nil
        CVPixelBufferCreate( kCFAllocatorDefault,
                             width,
                             height,
                             kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                             nil,
                             &pixelBuffer )
        
        return pixelBuffer
    }
    
    // convert the vImage buffer to CVPixelBuffer
    static func toCVPixelBuffer( vImgBuffer : UnsafeMutableRawPointer,
                                 pixelBuffer: CVPixelBuffer,
                                 targetWith: Int,
                                 targetHeight: Int,
                                 targetImageRowBytes: Int ) -> CVPixelBuffer?
    {
        let pixelBufferType = CVPixelBufferGetPixelFormatType( pixelBuffer )
        let releaseCallBack: CVPixelBufferReleaseBytesCallback =
        { mutablePointer, pointer in
            if let pointer = pointer
            {
                free( UnsafeMutableRawPointer( mutating: pointer ) )
            }
        }

        var targetPixelBuffer: CVPixelBuffer?
        let conversionStatus = CVPixelBufferCreateWithBytes( nil,
                                                             targetWith,
                                                             targetHeight,
                                                             pixelBufferType,
                                                             vImgBuffer,
                                                             targetImageRowBytes,
                                                             releaseCallBack,
                                                             nil,
                                                             nil,
                                                             &targetPixelBuffer )

        guard conversionStatus == kCVReturnSuccess else
        {
            free( vImgBuffer )
            return nil
        }

        return targetPixelBuffer
    }
    
    static func crop( pixelBuffer : CVPixelBuffer, to rect: CGRect ) -> CVPixelBuffer?
    {
        CVPixelBufferLockBaseAddress( pixelBuffer, .readOnly )
        defer { CVPixelBufferUnlockBaseAddress( pixelBuffer, .readOnly ) }

        guard let baseAddress = CVPixelBufferGetBaseAddress( pixelBuffer ) else { return nil }

        let inputImageRowBytes = CVPixelBufferGetBytesPerRow( pixelBuffer )

        let imageChannels = 4
        let startPos = Int( rect.origin.y ) * inputImageRowBytes + imageChannels * Int( rect.origin.x )
        let outWidth = UInt( rect.width )
        let outHeight = UInt( rect.height )
        let croppedImageRowBytes = Int( outWidth ) * imageChannels

        var inBuffer = vImage_Buffer()
        inBuffer.height = outHeight
        inBuffer.width = outWidth
        inBuffer.rowBytes = inputImageRowBytes

        inBuffer.data = baseAddress + UnsafeMutableRawPointer.Stride( startPos )

        guard let croppedImageBytes = malloc( Int( outHeight ) * croppedImageRowBytes ) else { return nil }

        var outBuffer = vImage_Buffer( data: croppedImageBytes, height: outHeight, width: outWidth, rowBytes: croppedImageRowBytes )

        let scaleError = vImageScale_CbCr8( &inBuffer, &outBuffer, nil, vImage_Flags( 0 ) )

        guard scaleError == kvImageNoError else
        {
            free( croppedImageBytes )
            return nil
        }

        return Util.toCVPixelBuffer( vImgBuffer: croppedImageBytes,
                                     pixelBuffer: pixelBuffer,
                                     targetWith: Int( outWidth ),
                                     targetHeight: Int( outHeight ),
                                     targetImageRowBytes: croppedImageRowBytes )
    }
}
