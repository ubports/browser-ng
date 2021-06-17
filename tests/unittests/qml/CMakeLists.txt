find_package(Qt5Core REQUIRED)
find_package(Qt5Gui REQUIRED)
find_package(Qt5Network REQUIRED)
find_package(Qt5Qml REQUIRED)
find_package(Qt5Quick REQUIRED)
find_package(Qt5QuickTest REQUIRED)
find_package(Qt5Sql REQUIRED)

find_program(XVFBRUN xvfb-run)
if(NOT XVFBRUN)
  message(FATAL_ERROR "Could not find xvfb-run, please install the xvfb package")
endif()
set(XVFB_COMMAND ${XVFBRUN} -s "-screen 0 640x480x24" -a)

set(TEST tst_QmlTests)
set(SOURCES
    ${webbrowser-common_SOURCE_DIR}/favicon-fetcher.cpp
    ${morph-browser_SOURCE_DIR}/bookmarks-model.cpp
    ${morph-browser_SOURCE_DIR}/bookmarks-folder-model.cpp
    ${morph-browser_SOURCE_DIR}/bookmarks-folderlist-model.cpp
    ${webbrowser-common_SOURCE_DIR}/file-operations.cpp
    ${morph-browser_SOURCE_DIR}/history-domain-model.cpp
    ${morph-browser_SOURCE_DIR}/history-domainlist-model.cpp
    ${morph-browser_SOURCE_DIR}/history-model.cpp
    ${morph-browser_SOURCE_DIR}/history-lastvisitdatelist-model.cpp
    ${morph-browser_SOURCE_DIR}/limit-proxy-model.cpp
    ${morph-browser_SOURCE_DIR}/reparenter.cpp
    ${morph-browser_SOURCE_DIR}/searchengine.cpp
    ${morph-browser_SOURCE_DIR}/tabs-model.cpp
    ${morph-browser_SOURCE_DIR}/text-search-filter-model.cpp
    tst_QmlTests.cpp
)
add_executable(${TEST} ${SOURCES})
include_directories(
    ${webbrowser-common_SOURCE_DIR}
    ${morph-browser_SOURCE_DIR}
    ${unity8_SOURCE_DIR}/plugins
)
target_link_libraries(${TEST}
    Qt5::Core
    Qt5::Gui
    Qt5::Network
    Qt5::Qml
    Qt5::Quick
    Qt5::QuickTest
    Qt5::Sql
)
add_test(${TEST} ${XVFB_COMMAND} ${CMAKE_CURRENT_BINARY_DIR}/${TEST}
         -input ${CMAKE_CURRENT_SOURCE_DIR}
         -import ${CMAKE_BINARY_DIR}/src)
