#ifndef TRANSFER_FUNCTION_INCLUDED
#define TRANSFER_FUNCTION_INCLUDED

#include "Assets/Shaders/Library/RayTracingMaterial.hlsl"

TEXTURE2D(_AlbedoTex);              SAMPLER(sampler_AlbedoTex);
TEXTURE2D(_RoughnessTex);           SAMPLER(sampler_RoughnessTex);
TEXTURE2D(_AlphaTex);               SAMPLER(sampler_AlphaTex);
TEXTURE2D(_MetallicTex);            SAMPLER(sampler_MetallicTex);

float _SigmaS;
float _Reflectance;

float _MinDensity;
float _MaxDensity;

float _GradientShift;
float _GradientLimit;

float DensityToSigma(float density)
{
    float density01 = InverseLerp(_MinDensity, _MaxDensity, density);
    float alpha = SAMPLE_TEXTURE2D_LOD(_AlphaTex, sampler_AlphaTex, float2(density01, 0.5), 0).a;
    return max(_SigmaS * alpha, 0.0000001);
}

RayTracingMaterial SampleMaterial(float density, float3 gradient)
{
    float density01 = InverseLerp(_MinDensity, _MaxDensity, density);
    density01 += _GradientShift * InverseLerp(0, _GradientLimit, length(gradient));
    
    RayTracingMaterial material = (RayTracingMaterial) 0;
    material.color = SAMPLE_TEXTURE2D_LOD(_AlbedoTex, sampler_AlbedoTex, float2(density01, 0.5), 0).rgb;
    material.roughness = pow(SAMPLE_TEXTURE2D_LOD(_RoughnessTex, sampler_RoughnessTex, float2(density01, 0.5), 0).a, 1 / 2.2);
    material.metallic = pow(SAMPLE_TEXTURE2D_LOD(_MetallicTex, sampler_MetallicTex, float2(density01, 0.5), 0).a, 1 / 2.2);
    material.reflectance = _Reflectance;
    return material;
}

#endif