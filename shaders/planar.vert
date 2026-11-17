#version 440
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float transitionEased;
    mat4 homography;
};

void main() {
    // Keep projective W through clip space for perspective-correct UV sampling.
    gl_Position = qt_Matrix * mix(qt_Vertex, homography * qt_Vertex,
                                 transitionEased);
    qt_TexCoord0 = qt_MultiTexCoord0;
}
