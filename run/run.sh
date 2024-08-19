#!/bin/bash

echo 'Running API'
pkill Floaty
./run-api.sh

echo 'Running VUE'
pkill node
./run-vue.sh

echo 'Running NGINX'
sudo nginx -s stop
sudo nginx -c "$(pwd)/../nginx.conf" || exit