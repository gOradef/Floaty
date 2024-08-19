#!/bin/bash

cd ../api/build || exit
cmake ..
cmake --build .

cd src/ || exit

sudo systemctl start postgresql.service
sudo ./Floaty &