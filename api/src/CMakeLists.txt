cmake_minimum_required(VERSION 3.5)

project(buildSrc)

set(LIBS_DIR ${CMAKE_SOURCE_DIR}/lib)
set(INCLUDES ${CMAKE_SOURCE_DIR}/include)

list(APPEND SOURCES
        connectionpool.cpp
        api.cpp
        server.cpp
        routes.cpp
        main.cpp
)
add_definitions(-DCROW_ENABLE_SSL)

add_executable(Floaty ${SOURCES})

# Set the public include directories for the Floaty target
target_include_directories(Floaty PUBLIC ${INCLUDES})

# Link the static library libpqxx.a from the ${LIBS_DIR} directory to the Floaty target
target_link_libraries(Floaty PUBLIC
        ${LIBS_DIR}/libpqxx.a
#        pqxx
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
        crypto
        ssl
)
