FROM ubuntu:latest
LABEL authors="goradef"

# Update package list and install necessary tools
RUN apt-get update && \
    apt-get install -y g++ cmake make boost1.83 libasio-dev libpq-dev && \
    apt-get clean

# Copy project files
#COPY ./api/include         /FloatyAPI/
#COPY ./api/lib             /FloatyAPI/
#COPY ./api/src             /FloatyAPI/
#COPY ./api/CMakeLists.txt  /FloatyAPI/
COPY ./api/                /FloatyAPI/

# Copy configuration file
COPY ./config.json         /FloatyAPI/

# Set working directory
WORKDIR /FloatyAPI

# Build the project
RUN cd /FloatyAPI && \
    mkdir -p build && \
    cd build && \
    rm CMakeCache.txt && \
    cmake .. && \
    make

# Copy the executable
RUN cp build/src/Floaty ./

# Define the command to run the executable
CMD ["./Floaty"]