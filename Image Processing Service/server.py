# Building Image service

import tornado.web
import tornado.ioloop
from processImage import addUserToCrowd

# server url
URL = 'http://localhost:4040/'

# upload image to the server
class uploadImgHandler(tornado.web.RequestHandler):
    # send upload portal to client
    def get(self):
        self.render("index.html")

    # uplaod image to img folder
    def post(self):
        if( 'image' in self.request.files ):
            # variables
            files = self.request.files["image"]
            f = files[0]
            imgPath = 'img/' + f.filename

            # save image
            fh = open( imgPath, "wb" )
            fh.write( f.body )
            fh.close()

            # process image
            addUserToCrowd( imgPath, imgPath )

            # send response back to client
            # self.write( URL + f"img/{f.filename}")
            self.redirect( URL + imgPath )
        else:
            self.write( 'No image uploaded' )


if (__name__ == "__main__"):
    app = tornado.web.Application([
        ("/", uploadImgHandler),
        ("/img/(.*)", tornado.web.StaticFileHandler, {"path" :"img"})
    ])

    app.listen(4040)
    print("Listening on port 4040")

    tornado.ioloop.IOLoop.instance().start()
