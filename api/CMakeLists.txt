cmake_minimum_required(VERSION 3.5)

project(FloatyAPI)

set(CPACK_GENERATOR "TGZ")
set(CPACK_PACKAGE_NAME "Floaty")
set(CPACK_PACKAGE_VERSION "1.0")
set(CPACK_PACKAGE_DESCRIPTION "My project")
set(CPACK_PACKAGE_VENDOR "My Company")


add_subdirectory(src)
