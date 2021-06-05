find_package(Qt5Core REQUIRED)
find_package(Qt5Test REQUIRED)
set(TEST tst_DomainUtilsTests)
add_executable(${TEST} tst_DomainUtilsTests.cpp)
include_directories(${webbrowser-common_SOURCE_DIR} ${webbrowser-plugin_SOURCE_DIR})
target_link_libraries(${TEST}
    Qt5::Core
    Qt5::Test
)
add_test(${TEST} ${CMAKE_CURRENT_BINARY_DIR}/${TEST})
