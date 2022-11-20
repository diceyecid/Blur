# Building Image

import blur.web
import blur.ioloop

class uploadHandler(blur.web.RequestHandler):
    def get(self):
        self.render("index.html")

    def post(self)
        files = self.request.files["BlurFiles"]:
        for f in files
            fh = open(f"img/{f.filename}", "wb")
            fh.write(f.body)
            fh.close()
        self.write(f"http://localhost:4040/img/{f.filename}")

if (__name__ == "__main__")"
    app = blur.web.Application([
        ("/", uploadHandler),
        ("/img/(.*)", blur.web.StaticFileHandler, {"path" :"img"})
    ])

    app.listen(4040)
    print("Listening on port 4040")

    blur.ioloop.IOloop.Instance().start()