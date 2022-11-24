from deepface.extendedmodels import Gender
import coremltools as ct


print( 'loading gender Keras model...' )
genderModel = Gender.loadModel()


print( 'converting Keras model to CoreML model...' )

# image preprocessing: colourChannel = colourChannel * scale + bias
imgShape = ( 1, 224, 224, 3 )
imgBias = [ 0, 0, 0 ]
imgScale = 1 / 255.0
imgInput = ct.ImageType( shape = imgShape, bias = imgBias, scale = imgScale )

# add classifiers
labels = [ 'Woman', 'Man' ]
imgClassifiers = ct.ClassifierConfig( labels )

# convert model
genderAppleModel = ct.convert( genderModel, 
                               convert_to = 'mlprogram',
                               inputs = [ imgInput ], 
                               classifier_config = imgClassifiers, )


print( 'saving CoreML model...' )
genderAppleModel.save( 'gender_model.mlpackage' )
