#ifndef VOLUME_RENDERING_INCLUDED
#define VOLUME_RENDERING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Common.hlsl"
#include "Assets/Shaders/Library/BRDF.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/Tricubic.hlsl"
#include "Assets/Shaders/Library/Octree.hlsl"
#include "Assets/Shaders/Library/Environment.hlsl"
#include "Assets/Shaders/Library/TransferFunction.hlsl"

float _StepSize;

float4 RayMarch(float3 position, Ray ray)
{
    HitInfo hitInfo = (HitInfo) 0;
    float4 output = 0;
    
    float tr = 1;
    
    float3 step = ray.dirOS * _StepSize;

    int steps = 0;
    
    [loop]
    for (int i = 0; i < 1000; i++)
    {
        position += step;
        steps++;
        
        if (!InVolumeBoundsOS(position))
        {
            break;
        }
        
        float3 uv = GetVolumeCoords(position);
        
        float3 gradient;
        float3 normal;
        SampleGradientAndNormal(uv, gradient, normal);
        
        float density = SampleDensity(uv);
        float sigma = DensityToSigma(density);
        
        hitInfo.material = SampleMaterial(density, gradient);
        
        float a = saturate(sigma * _StepSize);
        
        float3 normalWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, normal));
        float3 gi = SampleSH(normalWS);
        float3 pbr = PBRLighting(hitInfo.material.color, hitInfo.material.roughness, hitInfo.material.metallic, -ray.dirWS, normalWS, gi);
        
        //output.rgb += pbr * tr * a;
        output.rgb += gi * tr * a;
        
        tr *= (1.0 - a);
    }
    output.a = 1 - tr;
    return output;
}

float4 VolumeRenderingFragment(Varyings IN) : SV_TARGET
{
    Ray ray = GetRay(IN.uv, _VolumeWorldToLocalMatrix);
    
    float3 hitPoint;
    if (RayBoundingBoxOS(ray, hitPoint))
    {
        float4 output = RayMarch(hitPoint, ray);
        
        float4 skyData = SampleEnvironment(ray.dirWS, 0);
        
        return output + (1.0 - output.a) * skyData;
    }
    float4 skyData = SampleEnvironment(ray.dirWS, 0);
    return skyData;
}

#endif