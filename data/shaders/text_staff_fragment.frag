uniform sampler2D u_Tex0;      // Textura contendo as letras ou objetos (com bordas pretas)
uniform sampler2D u_Tex1;      // Textura a ser aplicada dentro da textura 1

varying vec2 v_TexCoord;       // Coordenadas de textura para u_Tex0
varying vec2 v_TexCoord2;      // Coordenadas de textura para u_Tex1

void main() {
    vec4 baseColor = texture2D(u_Tex0, v_TexCoord);  // Amostra a textura principal
    vec4 overlayColor = texture2D(u_Tex1, v_TexCoord2);  // Amostra a textura 2 com deslocamento

    if (baseColor.a > 0.1 && baseColor.rgb != vec3(0.0, 0.0, 0.0)) {
        gl_FragColor = vec4(overlayColor.rgb, baseColor.a); // Respeita o alpha de u_Tex0
    } else {
        gl_FragColor = baseColor;
    }
}
