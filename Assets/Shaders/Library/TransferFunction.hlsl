#ifndef TRANSFER_FUNCTION_INCLUDED
#define TRANSFER_FUNCTION_INCLUDED

#include "Assets/Shaders/Library/RayTracingMaterial.hlsl"

TEXTURE2D(_AlbedoTex);      SAMPLER(sampler_AlbedoTex);
TEXTURE2D(_RoughnessTex);   SAMPLER(sampler_RoughnessTex);
TEXTURE2D(_AlphaTex);       SAMPLER(sampler_AlphaTex);

float _SigmaT;

float _MinDensity;
float _MaxDensity;

float _GradientShift;
float _GradientLimit;

float DensityToSigma(float density)
{
    float density01 = InverseLerp(_MinDensity, _MaxDensity, density);
    float alpha = SAMPLE_TEXTURE2D_LOD(_AlphaTex, sampler_AlphaTex, float2(density01, 0.5), 0).a;
    return _SigmaT * alpha;
}

RayTracingMaterial SampleMaterial(float density, float3 gradient)
{
    float density01 = InverseLerp(_MinDensity, _MaxDensity, density);
    density01 += _GradientShift * InverseLerp(0, _GradientLimit, length(gradient));
    
    RayTracingMaterial material;
    material.color = SAMPLE_TEXTURE2D_LOD(_AlbedoTex, sampler_AlbedoTex, float2(density01, 0.5), 0).rgb;
    material.roughness = SAMPLE_TEXTURE2D_LOD(_RoughnessTex, sampler_RoughnessTex, float2(density01, 0.5), 0).a;
    return material;
}

#endif