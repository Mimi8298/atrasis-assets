#ifdef GL_ES
precision highp float;
#else
#define highp 
#define mediump 
#define lowp 
#endif

attribute vec4 a_pos;
attribute vec2 a_uv0;
attribute vec3 a_normal;

#ifdef NORMAL
attribute vec4 a_tangent;
#endif

#ifdef SUPPORTED_GL_OES_30
attribute mat4 a_model;
#else
uniform mat4 u_model;
#define a_model u_model
#endif

uniform mat4 u_view;
uniform mat4 u_projectionView;

varying mediump vec2 v_texCoord;
varying mediump vec3 v_normal;

#ifdef NORMAL
varying mediump vec3 v_tangent;
varying mediump vec3 v_binormal;
#endif

#ifdef PBR
varying mediump vec3 v_viewDir;
#endif

void main(void)
{
	vec4 pos = a_model * a_pos;

	v_texCoord.xy = a_uv0;

	// rotate to view space
	v_normal = normalize(vec3(u_view * (a_model * vec4(a_normal, 0.0))));
#ifdef NORMAL
	v_tangent = normalize(vec3(u_view * (a_model * vec4(a_tangent.xyz, 0.0))));
	v_binormal = normalize(cross(v_normal, v_tangent) * a_tangent.w);
#endif
	
#ifdef PBR
	v_viewDir = normalize(-vec3(u_view * pos));
#endif

	gl_Position = u_projectionView * pos;
}
