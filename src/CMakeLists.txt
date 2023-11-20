cmake_minimum_required(VERSION 3.5)
project(buildSrc)

message(STATUS "Setting virtual env's for build..")

set(HEADER_FILES ${CMAKE_CURRENT_SOURCE_DIR}/headerFiles/1.h)
set(DB_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/db_route/db_route.cpp)
set(SERVER_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/server_route/crow.cpp)
set(LIBS ${CMAKE_CURRENT_SOURCE_DIR}/libs/libmysqlcppconn.so)

message(STATUS "Starting build..")

link_libraries(${LIBS})
add_executable(Floaty ${DB_ROUTE} ${SERVER_ROUTE} ${HEADER_FILES})

message(STATUS "Starting build.. DONE")