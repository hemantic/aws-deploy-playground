import falcon
from envparse import env
import tasks


class CallbackIndex(object):
    def on_get(self, req, resp):
        resp.body = 'Its alive! Env value is: ' + env('SAMPLE_ENV_VAR')


class CallbackStartTask(object):
    def on_get(self, req, resp):
        tasks.calculate_square.delay(x=10)

        resp.body = 'Task added to queue'


app = falcon.API()

app.add_route('/', CallbackIndex())
app.add_route('/start_task', CallbackStartTask())
