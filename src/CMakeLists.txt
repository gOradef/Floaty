cmake_minimum_required(VERSION 3.5)
project(buildSrc)

message(STATUS "Setting virtual env's for build..")

set(DB_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/db_route/db_route.cpp)
set(SERVER_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/server_route/crow.cpp)
set(WEB_ROUTE ${CMAKE_CURRENT_SOURCE_DIR}/web_route/web.cpp)
set(LIBS ${CMAKE_SOURCE_DIR}/libs/libmysqlcppconn.so)
set(INCLUDES ${CMAKE_SOURCE_DIR}/includes)
list(APPEND SOURCES  ${DB_ROUTE} ${SERVER_ROUTE} ${WEB_ROUTE})
message(STATUS "Starting build..")

# link_libraries(${LIBS})
add_executable(Floaty ${SOURCES})
target_link_libraries(Floaty PRIVATE ${LIBS})
target_include_directories(Floaty PRIVATE ${INCLUDES})
message(STATUS "Starting build.. DONE")