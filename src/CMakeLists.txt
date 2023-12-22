cmake_minimum_required(VERSION 3.5)

include(../cmake/iflib-inc.cmake)

project(buildSrc)

message(STATUS "Setting virtual environment vars for build..")

set(AUTHENTICATION_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/authentication_route/authentication.cpp)
set(AUTHORIZATION_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/authorization_route/authorization.cpp)
set(SERVER_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/server_route/crow.cpp)
set(WEB_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/web_route/web.cpp)
set(API_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/api_route/api_route.cpp)
set(LIBS_DIR ${CMAKE_SOURCE_DIR}/libs)
set(INCLUDES ${CMAKE_SOURCE_DIR}/includes)

list(APPEND SOURCES  ${WEB_ROUTE} ${SERVER_ROUTE} ${AUTHENTICATION_ROUTE} ${AUTHORIZATION_ROUTE} ${API_ROUTE})

link_libraries(${LIBS_DIR}/libcrypto.so.3)
link_libraries(${LIBS_DIR}/libjsoncpp.so)
link_libraries(${LIBS_DIR}/libc.so.6)
link_libraries(${LIBS_DIR}/libgcc_s.so.1)
link_libraries(${LIBS_DIR}/libm.so.6)

add_executable(Floaty ${SOURCES})
target_include_directories(Floaty PRIVATE ${INCLUDES})
target_link_directories(Floaty PRIVATE ${LIBS_DIR})

target_link_libraries(Floaty PRIVATE iflib-inc)
