cmake_minimum_required(VERSION 3.5)

include(../cmake/iflib-inc.cmake)
project(buildSrc)

message(STATUS "Setting virtual environment vars for build..")

set(LIBS_DIR ${CMAKE_SOURCE_DIR}/libs)
set(INCLUDES ${CMAKE_SOURCE_DIR}/includes)

list(APPEND SOURCES
        server.cpp
        api_route.cpp
        authentication.cpp
        authorization.cpp
        web.cpp
        connectionpool.cpp
)
add_definitions(-DCROW_ENABLE_SSL)

#link_libraries(${LIBS_DIR}/libcrypto.so.3)
#link_libraries(${LIBS_DIR}/libjsoncpp.so)
#link_libraries(${LIBS_DIR}/libc.so.6)
#link_libraries(${LIBS_DIR}/libgcc_s.so.1)
#link_libraries(${LIBS_DIR}/libstdc++.so.6)
#link_libraries(${LIBS_DIR}/libm.so.6)
#find_package(openssl)
#link_libraries(${LIBS_DIR}/libssl.so.3)
add_executable(Floaty ${SOURCES}
        connectionpool.cpp)
target_include_directories(Floaty PRIVATE ${INCLUDES})

target_link_libraries(Floaty -L${LIBS_DIR})

target_link_libraries(Floaty
        -lcrypto
        -ljsoncpp
#        -lgcc
#        -lstdc++
        -lssl
        -lpqxx
)
