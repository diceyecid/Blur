# Building Image service

import tornado.web
import tornado.ioloop

class uploadImgHandler(tornado.web.RequestHandler):
    def get(self):
        self.render("index.html")

    def post(self):
        files = self.request.files["origin"]
        for f in files:
            fh = open(f"Img/{f.filename}", "wb")
            fh.write(f.body)
            fh.close()
        self.write(f"http://localhost:4040/Img/{f.filename}")


if (__name__ == "__main__"):
    app = tornado.web.Application([
        ("/", uploadImgHandler),
        ("/Img/(.*)", tornado.web.StaticFileHandler, {"path" :"Img"})
    ])

    app.listen(4040)
    print("Listening on port 4040")

    tornado.ioloop.IOLoop.instance().start()