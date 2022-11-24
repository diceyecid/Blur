import os
import cv2
import numpy as np
from rembg import remove

def alphaBlend( bg, fg, x, y ):
    out = bg.copy()

    # get the four coordinates
    y1, y2 = y, y + fg.shape[0]
    x1, x2 = x, x + fg.shape[1]

    # get alphas
    fgAlpha = fg[ :, :, 3 ] / 255.0
    bgAlpha = 1.0 - fgAlpha

    # compose images
    for ch in range( 0, 3 ):
        out[ y1:y2, x1:x2, ch ] = fgAlpha * fg[ :, :, ch ] + bgAlpha * bg[ y1:y2, x1:x2, ch ]

    return out

def addUserToCrowd( inputPath ):
    # remove user background
    userImg = cv2.imread( inputPath )
    userImg = remove( userImg )

    # get crowd image and add alpha
    crowdImg = cv2.imread( './crowd.png' )
    crowdAlpha = np.ones( ( crowdImg.shape[0], crowdImg.shape[1] ) )
    crowdImg = cv2.cvtColor( crowdImg, cv2.COLOR_BGR2BGRA )
    crowdImg[ :, :, 3 ] = crowdAlpha * 255

    # resize user image to 400px height
    h = 600
    aspectRatio = h / userImg.shape[0]
    w = int( userImg.shape[1] * aspectRatio )
    userImg = cv2.resize( userImg, ( w, h ) )
    
    # compose with crowd image
    yOffset = crowdImg.shape[0] - userImg.shape[0]
    xOffset = 700
    composedImg = alphaBlend( crowdImg, userImg, xOffset, yOffset )
    composedPath = './img/composed.png'
    cv2.imwrite( composedPath, composedImg )
    
    return composedImg, composedPath
