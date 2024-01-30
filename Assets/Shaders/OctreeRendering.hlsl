#ifndef OCTREE_RENDERING_INCLUDED
#define OCTREE_RENDERING_INCLUDED

#include "Assets/Shaders/Library/Common.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Octree.hlsl"
#include "Assets/Shaders/Library/Environment.hlsl"

float _Threshold;
int _OctreeLevel;


float4 RayMarch(float3 position, Ray ray)
{
    int steps = 0;
    
    int octreeLevel = 7;
    
    float3 uv = GetVolumeCoords(position);
    
    int3 octreeId = GetOctreeId(octreeLevel, uv);
    
    [loop]
    for (int i = 0; i < 1000; i++)
    {
        float value = GetOctreeValueById(octreeLevel, octreeId);
        
        // when the current cell is above the threshold, increase the octree level
        if (value > _Threshold)
        {
            break;
        }
        
        int3 lastId = octreeId;
        RayOctree(ray.dirOS, octreeLevel, octreeId, position);
        
        if (Equals(lastId, octreeId))
        {
            return float4(1, 0, 1, 1);
        }
        
        steps++;
        
        // Break when the octree id is out of bounds
        if (IsInvalid(octreeLevel, octreeId))
        {
            break;
        }
    }
    
    return (float) steps / 300.0;
}

float4 RayMarchOctree(float3 position, Ray ray)
{
    int steps = 0;
    
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
            IncreaseOctreeLevel(octreeLevel, octreeId, uv, _Threshold, _OctreeLevel);
            
            // When the threshold is reached on max level, break
            value = GetOctreeValueById(octreeLevel, octreeId);
            if (octreeLevel >= _OctreeLevel && value > _Threshold)
            {
                //return float4(GetOctreeNormal(octreeLevel, octreeId, uv) * 0.5 + 0.5, 1);
                break;
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
        
        int3 lastId = octreeId;
        RayOctree(ray.dirOS, octreeLevel, octreeId, position);
        
        if (Equals(lastId, octreeId))
        {
            return float4(1, 0, 1, 1);
        }
        
        steps++;
        
        // Break when the octree id is out of bounds
        if (IsInvalid(octreeLevel, octreeId))
        {
            break;
        }
    }
    
    return (float) steps / 80.0;
}

float4 OctreeFragment(Varyings IN) : SV_TARGET
{
    Ray ray = GetRay(IN.uv, _VolumeWorldToLocalMatrix);
    
    float3 hitPoint;
    if (RayBoundingBoxOS(ray, hitPoint))
    {
        float4 output = RayMarchOctree(hitPoint, ray);
        
        float4 skyData = SampleEnvironment(ray.dirWS, 0);
        
        return lerp(skyData, output, 0.95);
        
    }
    return SampleEnvironment(ray.dirWS, 0);
}

#endif