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

#ifdef SUPPORTED_GL_OES_30
attribute mat4 a_model;
#else
uniform mat4 u_model;
#define a_model u_model
#endif

uniform mat4 u_projectionView;
uniform mat4 u_view;
uniform vec3 u_camPos;

#ifdef SHADOWMAP
uniform mat4 u_shadowProjectionView;
varying vec4 v_shadowPosition;
#endif

varying vec2 v_texCoord;
varying highp vec3 v_normal;
varying highp vec3 v_viewDir;

void main(void)
{
	vec4 pos = a_model * a_pos;

	v_texCoord.xy = a_uv0;
	v_normal = vec3(a_model * vec4(a_normal, 0.0));
	v_viewDir = u_camPos - pos.xyz;
	
#ifdef SHADOWMAP
	v_shadowPosition = u_shadowProjectionView * pos;
#endif

	gl_Position = u_projectionView * pos;
}
