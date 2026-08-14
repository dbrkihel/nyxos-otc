uniform float u_Time;
uniform sampler2D u_Tex0;

varying vec2 v_TexCoord;

void main() {
    float distortion = sin(v_TexCoord.y * 50.0 + u_Time * 1.6) * 0.0015;
    vec2 heatUV = v_TexCoord + vec2(0.0, distortion);

    vec4 baseColor = texture2D(u_Tex0, heatUV);

    vec3 heatColor = vec3(1.0, 0.75, 0.4);  // cor quente
    float tintStrength = 0.15;

    vec3 finalColor = mix(baseColor.rgb, heatColor, tintStrength);

    gl_FragColor = vec4(finalColor, baseColor.a);
}
