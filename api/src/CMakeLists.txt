cmake_minimum_required(VERSION 3.5)

project(buildSrc)

set(LIBS_DIRECTORY "${CMAKE_SOURCE_DIR}/libs")
set(INCLUDES ${CMAKE_SOURCE_DIR}/includes)

list(APPEND SOURCES
        connectionpool.cpp
        api.cpp
        server.cpp
        routes.cpp
        main.cpp
)
add_definitions(-DCROW_ENABLE_SSL)

add_executable(Floaty ${SOURCES})

target_include_directories(Floaty PRIVATE ${INCLUDES})

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
