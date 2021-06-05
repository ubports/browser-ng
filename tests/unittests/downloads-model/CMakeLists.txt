find_package(Qt5Core REQUIRED)
find_package(Qt5Sql REQUIRED)
find_package(Qt5Test REQUIRED)
set(TEST tst_DownloadsModelTests)
add_executable(${TEST} tst_DownloadsModelTests.cpp)
include_directories(${webbrowser-common_SOURCE_DIR})
target_link_libraries(${TEST}
    Qt5::Core
    Qt5::Sql
    Qt5::Test
    webbrowser-common
    morph-browser-models
)
add_test(${TEST} ${CMAKE_CURRENT_BINARY_DIR}/${TEST})
set_tests_properties(${TEST} PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=minimal")
