from deepface.extendedmodels import Race
import coremltools as ct


print( 'loading race Keras model...' )
raceModel = Race.loadModel()


print( 'converting Keras model to CoreML model...' )

# image preprocessing: colourChannel = colourChannel * scale + bias
imgShape = ( 1, 224, 224, 3 )
imgBias = [ 0, 0, 0 ]
imgScale = 1 / 255.0
imgInput = ct.ImageType( shape = imgShape, bias = imgBias, scale = imgScale )

# add classifiers
labels = ['asian', 'indian', 'black', 'white', 'middle eastern', 'latino hispanic']
imgClassifiers = ct.ClassifierConfig( labels )

# convert model
raceAppleModel = ct.convert( raceModel, 
                             convert_to = 'mlprogram',
                             inputs = [ imgInput ], 
                             classifier_config = imgClassifiers, )


print( 'saving CoreML model...' )
raceAppleModel.save( 'race_model.mlpackage' )
