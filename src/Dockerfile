FROM python:3.8-slim

COPY requirements.txt ./

RUN apt-get update \
    && apt-get --no-install-recommends --assume-yes install build-essential \
    && apt-get --no-install-recommends --assume-yes install libpq-dev python-dev

RUN pip install --no-cache-dir -r requirements.txt

RUN pip install uwsgi

RUN mkdir -p /srv

WORKDIR /