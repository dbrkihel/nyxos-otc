uniform mat4 u_Color;
varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
void main()
{
    // True black silhouette: force EVERY visible outfit pixel to black, keeping
    // only its alpha (shape). The old shader only blackened the colorizable
    // (template-masked) pixels via texcolor.a > 0.1, so fixed-art pixels kept
    // their original colors and showed as coloured patches on the silhouette.
    vec4 col = texture2D(u_Tex0, v_TexCoord);
    if(col.a < 0.01) discard;
    gl_FragColor = vec4(0.0, 0.0, 0.0, col.a);
}