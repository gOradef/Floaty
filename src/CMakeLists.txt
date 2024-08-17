cmake_minimum_required(VERSION 3.5)

#include(../cmake/iflib-inc.cmake)
project(buildSrc)

set(LIBS_DIRECTORY "${CMAKE_SOURCE_DIR}/libs")
set(INCLUDES ${CMAKE_SOURCE_DIR}/includes)

list(APPEND SOURCES
        connectionpool.cpp
        api.cpp
        server.cpp
        main.cpp
)
add_definitions(-DCROW_ENABLE_SSL)

add_executable(Floaty ${SOURCES})

target_include_directories(Floaty PRIVATE ${INCLUDES})

#set_target_properties(Floaty PROPERTIES
#        INSTALL_RPATH "${LIBS_DIRECTORY}"
#        BUILD_WITH_INSTALL_RPATH TRUE
#)
#set(CMAKE_LIBRARY_PATH ${LIBS_DIRECTORY})

target_link_libraries(Floaty PRIVATE
        jsoncpp
        crypto
        ssl
        pqxx
        pq
        c
        com_err
        gcc

        gssapi_krb5
        keyutils
        k5crypto
        krb5
        krb5support
        lber
        ldap
        resolv
        sasl2
        stdc++
)
#if(UNIX AND NOT APPLE)
#    set_target_properties(Floaty PROPERTIES
#            INSTALL_RPATH_USE_LINK_PATH TRUE
#            INSTALL_RPATH ${LIBS_DIRECTORY}
#    )
#endif()
