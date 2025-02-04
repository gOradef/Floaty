#!/bin/bash

echo 'Running NGINX'
sudo nginx -s stop
sudo nginx -c "$(pwd)/nginx.conf" || exit

echo 'Running API'
pkill Floaty
./run-api.sh &

echo 'Running VUE'
pkill node
./run-vue.sh &
