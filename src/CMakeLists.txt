cmake_minimum_required(VERSION 3.5)
project(buildSrc)

message(STATUS "Setting virtual env's for build..")

set(AUTHENTICATION_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/authentication_route/authentication.cpp)
set(SERVER_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/server_route/crow.cpp)
set(WEB_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/web_route/web.cpp)

set(LIBS_DIR ${CMAKE_SOURCE_DIR}/libs)
set(INCLUDES ${CMAKE_SOURCE_DIR}/includes)
# set(CMAKE_CXX_FLAGS -lcrypto  -lssl )
list(APPEND SOURCES  ${WEB_ROUTE} ${SERVER_ROUTE} ${AUTHENTICATION_ROUTE})
message(STATUS "Starting build..")
#! -lstdc++ -lcrypto -lssl
# link_libraries(${LIBS_DIR})
link_libraries(${LIBS_DIR}/libcrypto.so.3)
link_libraries(${LIBS_DIR}/libjsoncpp.so)
add_executable(Floaty ${SOURCES})
target_include_directories(Floaty PRIVATE ${INCLUDES})
target_link_directories(Floaty PRIVATE ${LIBS_DIR})
message(STATUS "Starting build.. DONE")