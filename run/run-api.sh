#!/bin/bash

cd ../api/build || exit
cmake ..
cmake --build .

cd src/ || exit
sudo ./Floaty &