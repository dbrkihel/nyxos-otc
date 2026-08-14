uniform mat4 u_Color;
varying vec2 v_TexCoord;
varying vec2 v_TexCoord2;
varying vec2 v_TexCoord3;
uniform sampler2D u_Tex0;
uniform sampler2D u_Tex1;

void main()
{
    vec4 baseColor = texture2D(u_Tex0, v_TexCoord);
    vec4 texColor = texture2D(u_Tex0, v_TexCoord2);
    vec4 effectColor = texture2D(u_Tex1, v_TexCoord3);

    // Garante que effectColor não torne a cena totalmente preta
    // Ajustando a cor de efeito para ter um valor mínimo (por exemplo, não deixando ela ser mais escura que um certo limite)
    effectColor = max(effectColor, vec4(0.2, 0.2, 0.2, 1.0)); // Ajuste os valores conforme necessário para escurecer, mas mantendo um limite mínimo.

    if(texColor.a > 0.1) {
        baseColor *= effectColor;
    }

    gl_FragColor = baseColor;

    if(gl_FragColor.a < 0.01) discard;
}
