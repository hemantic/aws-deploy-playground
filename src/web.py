import falcon


class CallbackIndex(object):
    def on_get(self, req, resp):
        resp.body = 'Its alive!'


app = falcon.API()

app.add_route('/', CallbackIndex())
