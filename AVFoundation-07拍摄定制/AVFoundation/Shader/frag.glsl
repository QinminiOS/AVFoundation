precision mediump float;

uniform sampler2D image;
varying vec2 vTextureCoord;

void main()
{
    gl_FragColor = texture2D(image, vTextureCoord);
}
