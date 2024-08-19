#!/bin/bash

echo 'Running API'
./run-api.sh &

echo 'Running VUE'
./run-vue.sh &

echo 'Running NGINX'
sudo nginx -s stop
sudo nginx -c "$(pwd)/../nginx.conf" | exit