import falcon
from envparse import env


class CallbackIndex(object):
    def on_get(self, req, resp):
        resp.body = 'Its alive! Env value is: ' + env('SAMPLE_ENV_VAR')


app = falcon.API()

app.add_route('/', CallbackIndex())
