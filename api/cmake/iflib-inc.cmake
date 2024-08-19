include_guard(GLOBAL)

set(IFLIB_INC_TARGET_NAME iflib-inc)

set(IFLIB_INC_DIRS
        ../includes
)

file(GLOB_RECURSE IFLIB_INC_FILES
        ../includes/*.h
        ../includes/*.hpp
)

#message(STATUS "<------------------ IFLIB_INC_FILES = ${IFLIB_INC_FILES}")

add_library(${IFLIB_INC_TARGET_NAME} INTERFACE)
target_link_directories(${IFLIB_INC_TARGET_NAME} INTERFACE ${IFLIB_INC_DIRS})
target_sources(${IFLIB_INC_TARGET_NAME} INTERFACE ${IFLIB_INC_FILES})
