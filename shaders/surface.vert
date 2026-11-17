#version 440
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float transitionEased;
    float originX;
    float sourceU0;
    float sourceU1;
    vec2 topLeft;
    vec2 topRight;
    vec2 bottomLeft;
    vec2 bottomRight;
};

void main() {
    vec2 uv = qt_MultiTexCoord0;
    vec2 top = mix(topLeft, topRight, uv.x);
    vec2 bottom = mix(bottomLeft, bottomRight, uv.x);
    vec2 target = mix(top, bottom, uv.y) - vec2(originX, 0.0);
    vec2 position = mix(qt_Vertex.xy, target, transitionEased);
    gl_Position = qt_Matrix * vec4(position, qt_Vertex.zw);
    qt_TexCoord0 = vec2(mix(sourceU0, sourceU1, uv.x), uv.y);
}
