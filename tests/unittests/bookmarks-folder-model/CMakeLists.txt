find_package(Qt5Core REQUIRED)
find_package(Qt5Sql REQUIRED)
find_package(Qt5Test REQUIRED)
set(TEST tst_BookmarksFolderModelTests)
add_executable(${TEST} tst_BookmarksFolderModelTests.cpp)
include_directories(${morph-browser_SOURCE_DIR})
target_link_libraries(${TEST}
    Qt5::Core
    Qt5::Sql
    Qt5::Test
    morph-browser-models
)
add_test(${TEST} ${CMAKE_CURRENT_BINARY_DIR}/${TEST})
