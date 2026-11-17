cmake_minimum_required(VERSION 3.21)
project(PerspectiveNVP LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 ShaderTools)
qt_standard_project_setup(REQUIRES 6.5)
qt_add_executable(PerspectiveNVP main.cpp)
qt_add_qml_module(PerspectiveNVP
    URI PerspectiveNVP
    VERSION 1.0
    QML_FILES
        Main.qml
        LegacyDemo.qml
        SurfaceDemo.qml
        PerspectiveItem.qml
        PerspectiveSurface.qml
        VanishingPoint.qml
        PerspectiveMath.js
        SurfaceGeometry.js
)
qt_add_shaders(PerspectiveNVP surface_shaders
    BATCHABLE
    PREFIX "/shaders"
    FILES shaders/surface.vert shaders/planar.vert
)
set_target_properties(PerspectiveNVP PROPERTIES
        OUTPUT_NAME "PerspectiveNVPApp"
)
target_link_libraries(PerspectiveNVP PRIVATE Qt6::Quick Qt6::QuickControls2)

find_program(NODE_EXECUTABLE node)
if(NODE_EXECUTABLE)
    enable_testing()
    add_test(NAME planar_solver COMMAND ${NODE_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/test_solver.js)
    add_test(NAME surface_geometry COMMAND ${NODE_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/test_surface_geometry.js)
endif()
