cmake_minimum_required(VERSION 3.10)
project(LipiTSF)

# Output library will be a DLL
add_library(LipiTSF SHARED
    src/DllMain.cpp
    src/Globals.cpp
    src/Register.cpp
    src/ClassFactory.cpp
    src/LipiTSF.cpp
    src/IpcClient.cpp
    LipiTSF.def
)

# Specify C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Windows libraries required for TSF and COM
target_link_libraries(LipiTSF 
    user32
    advapi32
    ole32
    oleaut32
    uuid
)

# Need to export COM functions via the .def file
set_property(TARGET LipiTSF PROPERTY LINK_FLAGS "/DEF:\"${CMAKE_CURRENT_SOURCE_DIR}/LipiTSF.def\"")

# Definitions for Windows standard headers
target_compile_definitions(LipiTSF PRIVATE UNICODE _UNICODE WIN32 _WINDOWS)
