find_package(Qt5Sql REQUIRED)
find_package(Qt5Test REQUIRED)
set(TEST tst_HistoryLastVisitDateListModelTests)
add_executable(${TEST} tst_HistoryLastVisitDateListModelTests.cpp)
include_directories(${webbrowser-common_SOURCE_DIR} ${morph-browser_SOURCE_DIR})
target_link_libraries(${TEST}
    morph-browser-models
    Qt5::Sql
    Qt5::Test
)
add_test(${TEST} ${CMAKE_CURRENT_BINARY_DIR}/${TEST})
