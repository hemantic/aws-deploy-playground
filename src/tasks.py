from celery import Celery
from envparse import env


env.read_envfile()

celery = Celery('tasks')
celery.conf.update(
    broker_url=env('REDIS_URL'),
)


@celery.task
def calculate_square(x):
    return x * x
