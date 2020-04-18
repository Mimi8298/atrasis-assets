#ifdef GL_ES
#ifdef SUPPORTED_GL_EXT_shadow_samplers
#extension GL_EXT_shadow_samplers : require
#endif
precision highp float;
#else
#define highp 
#define mediump 
#define lowp 
#endif

#ifdef SHADOWMAP
varying vec4 v_shadowPosition;
#endif

varying vec2 v_texCoord;
varying highp vec3 v_normal;
varying highp vec3 v_viewDir;

#ifdef DIFFUSE_TEX
uniform sampler2D diffuseTex;
#endif
#ifdef SPECULAR_COLOR
uniform mediump vec4 u_specular;
#endif
#ifdef SPECULAR_TEX
uniform sampler2D specularTex;
#endif
#ifdef SHADOWMAP
#ifdef SUPPORTED_GL_EXT_shadow_samplers
uniform sampler2DShadow shadowmap;
#else
uniform sampler2D shadowmap;
#endif
#endif

void main (void)
{
	vec4 color = vec4(1.0);
	
#ifdef SPECULAR
	float spec = 0.0;
#endif
	
#ifdef DIFFUSE_TEX
	color = texture2D(diffuseTex, v_texCoord.xy);
#endif
#ifdef SPECULAR_TEX
	spec = texture2D(specularTex, v_texCoord.xy).r;
#endif

#ifdef SHADOWMAP
#ifdef SUPPORTED_GL_EXT_shadow_samplers
#ifdef GL_ES
	float shadowSample = shadow2DEXT(shadowmap, v_shadowPosition.xyz);
#else
	float shadowSample = shadow2D(shadowmap, v_shadowPosition.xyz).r;
#endif
#else
	float shadowSample = step(v_shadowPosition.z, texture2D(shadowmap, v_shadowPosition.xy).x);
#endif
	color.rgb *= mix( vec3( 0.75, 0.75, 0.75 ), vec3(1.0), shadowSample );
#endif

	// light
	vec3 u_lightIntensity = vec3(1.0, 1.0, 1.0);
	vec3 u_lightDir = vec3(0.0, 0.0, 0.0);

	vec3 n = normalize(v_normal);
	float ndl = max(dot(n, u_lightDir), 0.0);
	color.rgb *= (ndl * u_lightIntensity.x + u_lightIntensity.y);
	
#ifdef SPECULAR
	if (ndl > 0.0 && spec > 0.0 && u_lightIntensity.z > 0.0)
	{
		color.rgb += pow(max(dot(reflect(-u_lightDir, n), normalize(v_viewDir)), 0.0), u_lightIntensity.z) * spec;
	}
#endif

#ifdef GAMMA_CORRECT
	color = vec4(pow(color.rgb, vec3(0.454545)), color.a);
#endif

	gl_FragColor = color;
}
