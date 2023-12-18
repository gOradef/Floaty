cd cmake-build-debug &&
cmake --build . &&
cd src &&
cp ./Floaty ../.. &&
cd ../.. &&
./Floaty
