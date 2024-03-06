mkdir build -p &&
cd build &&
cmake .. &&
cmake --build . &&
cd src &&
cp ./Floaty ../.. &&
cd ../.. &&
./Floaty
