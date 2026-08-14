varying vec2 v_TexCoord;
uniform vec4 u_Color;
uniform sampler2D u_Tex0;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    float adjustmentFactor = 0.60; // Fator de ajuste para escurecer a cor

    // Multiplica cada componente de cor (RGB) pelo fator de ajuste
    vec4 darkerColor = vec4(texColor.rgb * adjustmentFactor, texColor.a);

    gl_FragColor = darkerColor * u_Color;
    if(gl_FragColor.a < 0.01)
        discard;
}
