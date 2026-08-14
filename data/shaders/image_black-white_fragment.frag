
varying vec2 v_TexCoord;
uniform vec4 u_Color;
uniform sampler2D u_Tex0;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    // Conversão para preto e branco
    float gray = dot(texColor.rgb, vec3(0.299, 0.587, 0.114));
	float adjustmentFactor = 0.025;
	gray = mix(gray, 1.0, adjustmentFactor); // Interpola entre cinza e branco
	vec4 grayScaleColor = vec4(gray, gray, gray, texColor.a);
    
    gl_FragColor = grayScaleColor * u_Color;
    if(gl_FragColor.a < 0.01)
        discard;
}
