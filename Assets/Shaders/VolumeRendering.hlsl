#ifndef VOLUME_RENDERING_INCLUDED
#define VOLUME_RENDERING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Common.hlsl"
#include "Assets/Shaders/Library/BRDF.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/Tricubic.hlsl"
#include "Assets/Shaders/Library/Classification.hlsl"
#include "Assets/Shaders/Library/Octree.hlsl"
#include "Assets/Shaders/Library/Environment.hlsl"

float _StepSize;
float _Threshold;
half4 _Color;

float _Roughness;
float _Metallicness;

TEXTURECUBE(_Skybox);       SAMPLER(sampler_Skybox);

HitInfo RaymarchCell(int level, int3 currentId, float3 position, float3 dirOS)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    if (false)
    {
        float3 uv = GetVolumeCoords(position);
        hitInfo.didHit = true;
        hitInfo.hitPointOS = position;
        hitInfo.normalOS = SampleNormal(uv);
        hitInfo.material.color = 0.5;
        return hitInfo;
    }
    
    float3 stopPos = position;
    RayOctree(dirOS, level, currentId, stopPos);
    
    // TODO: do i need to check at position and newPos ?
    float3 t = stopPos - position;
    float3 step = t / 15;
    for (int i = 0; i <= 15; i++)
    {
        float3 stepPos = position + i * step;
        
        float3 uv = GetVolumeCoords(stepPos);
        
        float4 classification = SampleClassification(uv);
        float maxValue = max(max(max(classification.r, classification.g), classification.b), classification.a);
                    
        if (maxValue > _Threshold) // Surface hit
        {
            hitInfo.didHit = true;
            hitInfo.hitPointOS = position;
            hitInfo.normalOS = SampleNormal(uv);
            //hitInfo.material.color = GetClassColor(classification);
            //hitInfo.material.color = SampleNormal(uv);
            
            hitInfo.material = GetMaterial(classification);
            
            return hitInfo;
        }
    }
    hitInfo.didHit = false;
    return hitInfo;
}

HitInfo TraverseOctree(float3 position, Ray ray)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    int octreeLevel = 0;
    float3 uv = GetVolumeCoords(position);
    int3 octreeId = GetOctreeId(octreeLevel, uv);
    
    [loop]
    for (int i = 0; i < 256; i++)
    {
        float value = GetOctreeValueById(octreeLevel, octreeId);
        
        // when the current cell is above the threshold, increase the octree level
        if (value > _Threshold)
        {
            uv = GetVolumeCoords(position);
            
            IncreaseOctreeLevel(octreeLevel, octreeId, uv, _Threshold);
            
            // When the threshold is reached on max level, break
            value = GetOctreeValueById(octreeLevel, octreeId);
            if (octreeLevel >= 7 && value > _Threshold)
            {
                hitInfo = RaymarchCell(octreeLevel, octreeId, position, ray.dirOS);
                
                if (hitInfo.didHit)
                {
                    return hitInfo;
                }
            }
        }
        else
        {
            // Check if the octree level can be lowered again
            if (octreeLevel > 0)
            {
                ReduceOctreeLevel(octreeLevel, octreeId, _Threshold);
            }
        }
        
        RayOctree(ray.dirOS, octreeLevel, octreeId, position);
        
        // Break when the octree id is out of bounds
        if (IsInvalid(octreeLevel, octreeId))
        {
            break;
        }
    }
    return hitInfo;
}

float4 RayMarch(float3 position, Ray ray)
{
    float3 step = ray.dirOS * _StepSize;
    float4 output = 0;

    int steps = 0;
    
    [loop]
    for (int i = 0; i < 720; i++)
    {
        position += step;
        steps++;
        
        if (!InVolumeBoundsOS(position))
        {
            break;
        }
        
        float3 uv = GetVolumeCoords(position);
        
        float4 value = SampleClassification(uv);
        
        //float4 value = tex3DTricubic(_ClassifyTex, sampler_ClassifyTex, uv, float3(512, 512, 460));
        
        float maxVal = max(max(max(value.r, value.g), value.b), value.a);
        
        if (maxVal > _Threshold)
        {
            half3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
            
            float3 normalWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, gradient));
            
            float4 color = GetClassColor(value);
            
            float3 gi = SampleSH(normalWS);
            color.rgb = PBRLighting(color.rgb, 0, _Metallicness, -ray.dirWS, normalWS, gi);
            output.rgb = color;
            output.a = 1;
            
            break;
        }
    }
    
    return output;
}

float4 VolumeRenderingFragment(Varyings IN) : SV_TARGET
{
    Ray ray = GetRay(IN.uv);
    
    float3 hitPoint;
    if (RayBoundingBoxOS(ray, hitPoint))
    {
        HitInfo hitInfo = TraverseOctree(hitPoint, ray);
        if (hitInfo.didHit)
        {
            float3 normalWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, hitInfo.normalOS));
            float3 gi = SampleSH(normalWS);
            float4 output = 0;
            output.rgb = PBRLighting(hitInfo.material.color, hitInfo.material.roughness, hitInfo.material.metallicness, -ray.dirWS, normalWS, gi);
            output.a = 1;
            
            return output;
        }

    }
    float4 skyData = SampleEnvironment(ray.dirWS, 0);
    return skyData;
}

#endif