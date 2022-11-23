import os
import cv2
from rembg import remove

def addUserToCrowd( inputPath, outputPath ):
    # set output image as a PNG as it can save transparency
    filename, fileExt = os.path.splitext( outputPath )
    outputPath = filename + '.png'
    
    # remove background
    inputImg = cv2.imread( inputPath )
    outputImg = remove( inputImg )
    cv2.imwrite( outputPath, outputImg )

    return outputImg, outputPath
