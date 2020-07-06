
#ifdef GL_ES
precision mediump float;

#else
#define highp 
#define mediump
#define lowp 
#endif

#define RGBM_MULTIPLIER_SPECULAR 16.0
#define RGBM_MULTIPLIER_DIFFUSE 2.0

#ifdef PBR

#define METALLIC r
#define ROUGHNESS g
#define AO b

#ifdef USE_MIPMAPS
#define MAX_SPECULAR_LOD 5.0
// make sure we find a suitable method for showing filtered specular
#extension GL_EXT_shader_texture_lod: enable

#ifdef GL_EXT_shader_texture_lod

#ifdef GL_ES
#define scTextureLod(s,c,lod) texture2DLodEXT(s,c,lod * MAX_SPECULAR_LOD)
#else
#define scTextureLod(s,c,lod) texture2DLod(s,c,lod * MAX_SPECULAR_LOD)
#endif

#else // GL_ES

#ifndef GL_ES
#extension GL_ARB_shader_texture_lod: enable
#endif

#ifdef GL_ARB_shader_texture_lod
#define scTextureLod(s,c,lod) texture2DLod(s,c,lod * MAX_SPECULAR_LOD)
#else
#define scTextureLod(s,c,lod) mix(texture2D(s,c,lod * MAX_SPECULAR_LOD), vec4(1.0, 1.0, 1.0, 0.046), lod)
#endif

#endif // GL_ES

#else // USE_MIPMAPS

#define TEXTURE_HEIGHT 144.0
#define BORDER_SIZE (4.0 / TEXTURE_HEIGHT)
#define MIP1 ((64.0 / TEXTURE_HEIGHT) + BORDER_SIZE)
#define MIP2 ((32.0 / TEXTURE_HEIGHT) + BORDER_SIZE)
#define MIP3 ((16.0 / TEXTURE_HEIGHT) + BORDER_SIZE)
#define MIP4 ((8.0 / TEXTURE_HEIGHT) + BORDER_SIZE)
#define MIP5 ((4.0 / TEXTURE_HEIGHT) + BORDER_SIZE)

#define MAX_SPECULAR_LOD 4.0
vec4 scTextureLod(sampler2D s, vec2 c, float lod)
{
	lod = clamp(lod * MAX_SPECULAR_LOD, 0.0, MAX_SPECULAR_LOD - 0.0001);
	float lodF = fract(lod);
	float level = floor(lod);
	
	vec2 mip = exp2((MAX_SPECULAR_LOD + 1.0) - level) / vec2(32.0, TEXTURE_HEIGHT * 0.5);
	
	float y = 
		MIP1 * step(1.0, level) +
		MIP2 * step(2.0, level) +
		MIP3 * step(3.0, level);
	
	vec4 s0 = texture2D(s, c * mip + vec2(0.0, y));
	vec4 s1 = texture2D(s, c * mip * 0.5 + vec2(0.0, y + mip.y + BORDER_SIZE));
	return mix(s0, s1, lodF);
}

#endif // USE_MIPMAPS

#endif // PBR

varying mediump vec2 v_texCoord;
varying mediump vec3 v_normal;

#ifdef NORMAL
varying mediump vec3 v_tangent;
varying mediump vec3 v_binormal;
#endif

#ifdef DIFFUSE_TEX
uniform mediump sampler2D diffuseTex;
#endif
#ifdef SPECULAR_TEX
uniform mediump sampler2D specularTex;
#endif
#ifdef NORMAL
uniform mediump sampler2D normalTex;
#endif
#ifdef EMISSION_TEX
uniform mediump sampler2D emissionTex;
#endif
#ifdef EMISSION_COLOR
uniform mediump vec4 u_emission;
#endif

uniform mediump sampler2D lightmapDiffuse;
#ifdef SPECULAR
uniform mediump sampler2D lightmapSpecular;
#endif

#ifdef PBR
#define materialTex specularTex
varying mediump vec3 v_viewDir;
#endif

#ifdef OPACITY_TEX
uniform mediump sampler2D opacityTex;
#endif
#ifdef OPACITY_VALUE
uniform mediump float u_opacity;
#endif
#ifdef COLORIZE_COLOR
uniform mediump vec4 u_colorize;
#endif
#ifdef COLORTRANSFORM_MUL
uniform mediump vec4 u_colorMul;
#endif
#ifdef COLORTRANSFORM_ADD
uniform mediump vec4 u_colorAdd;
#endif

#ifdef GAMMA_CORRECT
#define SRGB_TO_LINEAR(v) pow(v, vec3(2.2))
#define LINEAR_TO_SRGB(v) pow(v, vec3(0.4545))
#else
#define SRGB_TO_LINEAR(v) v
#define LINEAR_TO_SRGB(v) v
#endif

#ifdef PBR
// Environment BRDF approximation based on: https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile
vec3 envBRDFApprox(vec3 specularColor, float roughness, float ndv)
{
	vec4 c0 = vec4(-1, -0.0275, -0.572, 0.022);
	vec4 c1 = vec4( 1,  0.0425,  1.04, -0.04);
	vec4 r = roughness * c0 + c1;
	float a004 = min(r.x * r.x, exp2(-9.28 * ndv)) * r.x + r.y;
	vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
	return specularColor * AB.x + AB.y;
}
#endif

void main (void)
{
#ifdef NORMAL
	vec3 normalSample = texture2D(normalTex, v_texCoord).rgb * 2.0 - 1.0;
	vec3 n = normalize(normalize(v_tangent) * normalSample.x + normalize(v_binormal) * normalSample.y + normalize(v_normal) * normalSample.z);
#else
	vec3 n = normalize(v_normal);
#endif

	vec2 ibl_uv = vec2(n.x, -n.y) * 0.5 + 0.5;
	vec4 diffuse = texture2D(lightmapDiffuse, ibl_uv);
	diffuse.rgb *= (RGBM_MULTIPLIER_DIFFUSE * diffuse.a);

#ifdef DIFFUSE_TEX
	vec4 albedo = texture2D(diffuseTex, v_texCoord.xy);
	albedo.rgb = SRGB_TO_LINEAR(albedo.rgb);
#else
	vec4 albedo = vec4(1.0);
#endif

#ifdef COLORIZE_COLOR
	albedo *= u_colorize;
#endif

#ifdef PBR

	// r = metallic, g = roughness, b = ao
	vec3 material = texture2D(materialTex, v_texCoord.xy).rgb;
	//vec3 material = vec3(1.0, 0.16666 * 3.0, 1.0);
	float roughness = material.ROUGHNESS;
	
	// read specular map as RGBM
	//float lod = roughness * (1.7 - 0.7 * roughness);
	vec4 specular = scTextureLod(lightmapSpecular, ibl_uv, roughness);
	specular.rgb *= (RGBM_MULTIPLIER_SPECULAR * specular.a);
	
	float ndv = max(dot(n, normalize(v_viewDir)), 0.0);
	vec3 F0 = mix(vec3(0.04), albedo.rgb, material.METALLIC);
	float f = 1.0 - ndv;
	f *= f;
	vec3 F = F0 + (max(vec3(1.0 - roughness), F0) - F0) * (f*f);

	vec3 brdf = envBRDFApprox(F, roughness, ndv);
	vec4 color = vec4((material.AO * (1.0 - material.METALLIC)) * (1.0 - F) * diffuse.rgb * albedo.rgb + specular.rgb * brdf, albedo.a);
	
#else	// PBR

#ifdef SPECULAR
#ifdef SPECULAR_TEX
	vec3 spec = texture2D(specularTex, v_texCoord.xy).rgb;
#else
	vec3 spec = vec3(0.0);
#endif
#endif

	vec4 color = vec4(albedo.rgb * diffuse.rgb, albedo.a);
#ifdef SPECULAR
	vec3 specular = SRGB_TO_LINEAR(texture2D(lightmapSpecular, ibl_uv).rgb);
	color.rgb += spec * specular;
#endif

#endif	// PBR

#ifdef EMISSION_TEX
	vec3 emission = SRGB_TO_LINEAR(texture2D(emissionTex, v_texCoord).rgb);
	color.rgb += emission;
#endif
#ifdef EMISSION_COLOR
	color.rgb += u_emission.rgb;
#endif

// debug stuff
#ifdef DEBUG

#ifdef DEBUG_ALBEDO
	color = albedo;
#endif

#ifdef DEBUG_NORMALS
	color.rgb = abs(n);
#endif

#ifdef DEBUG_VERTEX_NORMALS
	color.rgb = abs(normalize(v_normal));
#endif

#ifdef DEBUG_SPEC
#ifndef PBR
#ifdef SPECULAR
	color.rgb = spec;
#endif
#endif
#endif

#ifdef DEBUG_MATERIAL_METALLIC
#ifdef PBR
	color.rgb = material.rrr;
#endif
#endif

#ifdef DEBUG_MATERIAL_ROUGHNESS
#ifdef PBR
	color.rgb = material.ggg;
#endif
#endif

#ifdef DEBUG_MATERIAL_AO
#ifdef PBR
	color.rgb = material.bbb;
#endif
#endif
#ifdef DEBUG_LIGHTMAP_DIFFUSE
#ifdef LIGHTMAP
	color.rgb = diffuse.rgb;
#endif
#endif

#ifdef DEBUG_LIGHTMAP_SPECULAR
#ifdef LIGHTMAP
#ifdef SPECULAR
	color.rgb = specular.rgb;
#endif
#endif
#endif

#ifdef DEBUG_LIGHTMAP_SPECULAR_MIP0
#ifdef PBR
	vec4 t = scTextureLod(lightmapSpecular, ibl_uv, 0.0);
	color.rgb = t.rgb * (RGBM_MULTIPLIER_SPECULAR * t.a);
#endif
#endif

#ifdef DEBUG_LIGHTMAP_SPECULAR_MIP1
#ifdef PBR
	vec4 t = scTextureLod(lightmapSpecular, ibl_uv, 1.0 / MAX_SPECULAR_LOD);
	color.rgb = t.rgb * (RGBM_MULTIPLIER_SPECULAR * t.a);
#endif
#endif

#ifdef DEBUG_LIGHTMAP_SPECULAR_MIP2
#ifdef PBR
	vec4 t = scTextureLod(lightmapSpecular, ibl_uv, 2.0 / MAX_SPECULAR_LOD);
	color.rgb = t.rgb * (RGBM_MULTIPLIER_SPECULAR * t.a);
#endif
#endif

#ifdef DEBUG_LIGHTMAP_SPECULAR_MIP3
#ifdef PBR
	vec4 t = scTextureLod(lightmapSpecular, ibl_uv, 3.0 / MAX_SPECULAR_LOD);
	color.rgb = t.rgb * (RGBM_MULTIPLIER_SPECULAR * t.a);
#endif
#endif

#ifdef DEBUG_LIGHTMAP_SPECULAR_MIP4
#ifdef PBR
	vec4 t = scTextureLod(lightmapSpecular, ibl_uv, 4.0 / MAX_SPECULAR_LOD);
	color.rgb = t.rgb * (RGBM_MULTIPLIER_SPECULAR * t.a);
#endif
#endif

#ifdef DEBUG_PBR_DIFFUSE_TERM
#ifdef PBR
	color.rgb = (material.AO * (1.0 - material.METALLIC)) * (1.0 - F) * diffuse.rgb * albedo.rgb;
#else
	color.rgb = albedo.rgb * diffuse.rgb;
#endif
#endif

#ifdef DEBUG_PBR_SPECULAR_TERM
#ifdef PBR
	color.rgb = specular.rgb * brdf;
#else
#ifdef SPECULAR
	color.rgb = spec * specular;
#endif
#endif
#endif

#ifdef DEBUG_EMISSION
#ifdef EMISSION_TEX
	color.rgb = emission;
#endif
#endif

#ifdef DEBUG_OPACITY
#ifdef OPACITY_TEX
	color.rgb = texture2D(opacityTex, v_texCoord).rrr;
#else
#ifdef OPACITY_VALUE
	color.rgb = vec3(u_opacity);
#else
	color.rgb = vec3(1.0);
#endif
#endif
#endif

#endif

#ifndef DEBUG_OPACITY
#ifdef OPACITY_TEX
	color *= texture2D(opacityTex, v_texCoord).r;
#endif
#ifdef OPACITY_VALUE
	color *= u_opacity;
#endif
#endif

#ifdef COLORTRANSFORM_MUL
	color *= u_colorMul;
#endif
#ifdef COLORTRANSFORM_ADD
	color += u_colorAdd * color.a;
#endif

	gl_FragColor = vec4(LINEAR_TO_SRGB(color.rgb), color.a);
}
