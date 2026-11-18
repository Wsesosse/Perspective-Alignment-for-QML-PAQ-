#version 440
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float transitionEased;
    float sourceU0;
    float sourceU1;
    float creaseU;
    float scaleU;
    float scaleV;
    float cameraTilt;
    float focalX;
    float focalY;
    float fisheyeF;
    float viewportWidth;
    float viewportHeight;
    float centerX;
    float centerY;
    float sheetX;
    float sheetY;
    float patchOriginX;
    int projectionKind;
    int surfaceMode;
    vec3 anchor3D;
    vec3 uDirection3D;
    vec3 vDirection3D;
};

void main() {
    vec2 uv=qt_MultiTexCoord0;
    float u=mix(sourceU0,sourceU1,uv.x);
    float originU=surfaceMode==1 ? creaseU : 0.5;
    vec3 world=anchor3D + (u-originU)*scaleU*uDirection3D
              + (uv.y-0.5)*scaleV*vDirection3D;
    float co=cos(cameraTilt),si=sin(cameraTilt);
    vec3 camera=vec3(world.x,co*world.y-si*world.z,
                     si*world.y+co*world.z);
    vec2 projected;
    if(projectionKind==0) {
        float z=max(camera.z,0.0001);
        projected=vec2(centerX+focalX*camera.x/z,
                       centerY+focalY*camera.y/z);
    } else if(projectionKind==1) {
        float rho=length(camera.xy);
        float theta=atan(rho,camera.z);
        projected=vec2(centerX,centerY);
        if(rho>0.000001)
            projected += fisheyeF*theta*camera.xy/rho;
    } else {
        float longitude=atan(camera.x,camera.z);
        float latitude=atan(camera.y,length(camera.xz));
        projected=vec2(centerX+viewportWidth*longitude/(2.0*3.141592653589793),
                       centerY+viewportHeight*latitude/3.141592653589793);
        if(projected.x>=viewportWidth) projected.x-=viewportWidth;
        if(projected.x<0.0) projected.x+=viewportWidth;
    }
    vec2 target=projected-vec2(sheetX+patchOriginX,sheetY);
    if(projectionKind==0 && transitionEased>=0.999999) {
        // Preserve projective W so one planar patch has exact UV interpolation.
        float w=max(camera.z,0.0001);
        gl_Position=qt_Matrix*vec4(target*w,0.0,w);
    } else {
        gl_Position=qt_Matrix*vec4(mix(qt_Vertex.xy,target,transitionEased),0.0,1.0);
    }
    qt_TexCoord0=vec2(u,uv.y);
}
