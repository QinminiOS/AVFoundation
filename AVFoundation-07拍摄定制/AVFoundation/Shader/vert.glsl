attribute vec3 position;
attribute vec2 textureCoord;

varying vec2 vTextureCoord;

void main()
{
    const float degree = radians(-90.0);
    
    const mat3 rotate = mat3(cos(degree), sin(degree), 0.0,
                             -sin(degree), cos(degree), 0.0,
                             0.0, 0.0, 1.0);
    
    gl_Position = vec4(rotate*position, 1.0);
    vTextureCoord = textureCoord;
}
