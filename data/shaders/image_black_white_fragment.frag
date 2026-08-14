varying vec2 v_TexCoord;
uniform vec4 u_Color;
uniform sampler2D u_Tex0;
uniform float u_Time; // Tempo em segundos

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);

    // Calcula se estamos em um intervalo par ou ímpar de 750ms
    // 0.75 segundos são 3/4 de um segundo, então multiplicamos u_Time por 4/3 e verificamos a paridade.
    bool isEvenInterval = mod(floor(u_Time * (4.0 / 3.0)), 2.0) == 0.0;

    // Alternando entre preto e branco-meio-cinza
    vec4 color;
    if (isEvenInterval) {
        color = vec4(0.8, 0.8, 0.8, texColor.a); // Branco-meio-cinza
    } else {
        color = vec4(0.0, 0.0, 0.0, texColor.a); // Preto
    }

    gl_FragColor = color * u_Color;
    if(gl_FragColor.a < 0.01)
        discard;
}
