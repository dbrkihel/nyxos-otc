attribute vec2 a_TexCoord;
attribute vec2 a_Vertex;

uniform mat3 u_TextureMatrix;
uniform mat3 u_TransformMatrix;
uniform mat3 u_ProjectionMatrix;

uniform vec2 u_Offset;
uniform float u_Time;

vec2 u_Direction = vec2(1.0,0.2);
float u_Speed = 100.0;
vec2 u_EffectTextureSize = vec2(609.0, 559.0);

varying vec2 v_TexCoord;
varying vec2 v_TexCoord2;

void main() {
    vec3 adjustedVertex = vec3(a_Vertex + u_Offset, 1.0);
    gl_Position = vec4((u_ProjectionMatrix * u_TransformMatrix * adjustedVertex).xy, 0.0, 1.0);

    v_TexCoord = (u_TextureMatrix * vec3(a_TexCoord, 1.0)).xy;

    v_TexCoord2 = ((a_Vertex + u_Direction * u_Time * u_Speed) / u_EffectTextureSize);
}
