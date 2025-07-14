#!/bin/bash
service nginx start
cd /build/api
gunicorn --workers 3 --bind 127.0.0.1:5000 -m 007 wsgi:app
while true ; do sleep 3600 ; done