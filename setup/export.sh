#!/bin/bash

mkdir ../deploy

echo '--- Started Vue prepare'
cd ../front
npm run build

cp ./dist ./public ../deploy -r

echo '--- Started API prepare'
mkdir ../deploy/api
cd ../api
cp CMakeLists.txt cmake include lib src ../deploy/api -r

echo '--- Started configs prepare'
cd ..
cp run services setup ./deploy -r

