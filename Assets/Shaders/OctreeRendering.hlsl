#ifndef OCTREE_RENDERING_INCLUDED
#define OCTREE_RENDERING_INCLUDED

#include "Assets/Shaders/Library/Common.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Octree.hlsl"

float _Threshold;
int _OctreeLevel;

struct Parent
{
    int3 ids[7];
};

int3 GetChildOctreeId(int parentLevel, int3 parentId, float3 uv)
{
    // Calculate the inner borders between the 8 child cells
    float dim = OCTREE_DIM[parentLevel];
    float3 innerBorder01 = (((float3) parentId + float3(0.5, 0.5, 0.5)) / (float) dim);
    
    // Child id is in range [2 * parentId, 2 * parentId + 1]
    int3 offset = 0;
    offset.x = (uv.x > innerBorder01.x) ? 1 : 0;
    offset.y = (uv.y > innerBorder01.y) ? 1 : 0;
    offset.z = (uv.z > innerBorder01.z) ? 1 : 0;
    
    int3 childId = parentId * 2 + offset;
    return childId;
}

void IncreaseOctreeLevel(int level, int3 octreeId, float3 uv, out int newLevel, out int3 newId)
{
    newLevel = level;
    newId = octreeId;
    
    while (newLevel < _OctreeLevel)
    {
        newId = GetChildOctreeId(newLevel, newId, uv);
        
        newLevel++;
        
        float value = GetOctreeValueById(newLevel, newId);
        
        if (value <= _Threshold)
        {
            break;
        }
    }
}

void IncreaseOctreeLevel(inout int level, inout int3 octreeId, float3 uv)
{
    while (level < _OctreeLevel)
    {
        octreeId = GetChildOctreeId(level, octreeId, uv);
        level++;
        
        
        // When value is lesser than threshold, stay on this level
        float value = GetOctreeValueById(level, octreeId);
        if (value <= _Threshold)
        {
            break;
        }
    }
}

int IncreaseOctreeLevel(int level, float3 uv)
{
    int newLevel = level;
    while (newLevel < _OctreeLevel)
    {
        newLevel++;
        float value = GetOctreeValue(newLevel, uv);
        
        if (value <= _Threshold)
        {
            break;
        }
    }
    return newLevel;
}

bool Equals(int3 a, int3 b)
{
    return a.x == b.x && a.y == b.y && a.z == b.z;
}

float4 RayMarchOctree(float3 position, Ray ray)
{
    float4 output = 0;

    int steps = 0;
    
    int octreeLevel = 0;
    
    float octreeDim = OCTREE_DIM[octreeLevel];
    
    float3 uv = GetVolumeCoords(position);
    
    // Octree id
    int3 parentId;
    int3 octreeId = GetOctreeId(octreeLevel, uv);
    
    [loop]
    for (int i = 0; i < 256; i++)
    {
        float value = GetOctreeValueById(octreeLevel, octreeId);
        
        // when the current cell is above the threshold, increase the octree level
        if (value > _Threshold)
        {
            uv = GetVolumeCoords(position);
            
            IncreaseOctreeLevel(octreeLevel, octreeId, uv);
            
            // When the threshold is reached on max level, break
            value = GetOctreeValueById(octreeLevel, octreeId);
            if (value > _Threshold)
            {
                break;
            }
        }
        else
        {
            // Check if the octree level can be lowered again
            if (octreeLevel > 0)
            {
                for (int p = 0; p < 8; p++)
                {
                    if (octreeLevel <= 0)
                        break;
                    
                    int3 currentParentId = floor(octreeId / 2);
                    float parentValue = GetOctreeValueById(octreeLevel - 1, currentParentId);
                    if (parentValue <= _Threshold)
                    {
                        octreeLevel--;
                        octreeId = currentParentId;
                        currentParentId = floor(octreeId / 2);
                    }
                    else
                    {
                        break;
                    }
                }
            }
        }
        
        float3 hitPoint;
        int3 nextId;
        RayOctree(octreeLevel, octreeId, position, ray.dirOS, nextId, hitPoint);
        
        if (nextId.x == octreeId.x && nextId.y == octreeId.y && nextId.z == octreeId.z)
        {
            return float4(0, 1, 0, 1);
        }
            
        position = hitPoint;
        octreeId = nextId;
        steps++;
        
        // Break when the octree id is out of bounds
        if (IsInvalid(octreeLevel, octreeId))
        {
            break;
        }
    }
    
    //return output;
    
    return (float) steps / 80.0;
}

float4 OctreeFragment(Varyings IN) : SV_TARGET
{
    Ray ray = GetRay(IN.uv);
    
    float3 hitPoint;
    if (RayBoundingBoxOS(ray, hitPoint))
    {
        float4 output = RayMarchOctree(hitPoint, ray);
        return output;
        
    }
    return float4(0, 0, 0, 1);
}

#endif