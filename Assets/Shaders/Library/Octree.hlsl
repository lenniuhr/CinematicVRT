#ifndef OCTREE_INCLUDED
#define OCTREE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/Library/OctreeUtils.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"

StructuredBuffer<float> _OctreeBuffer;
int _OctreeDepth;

float GetOctreeValue(int level, float3 uv)
{
    int dim = OCTREE_DIM[level];
    
    int x = clamp(floor(uv.x * dim), 0, dim - 1);
    int y = clamp(floor(uv.y * dim), 0, dim - 1);
    int z = clamp(floor(uv.z * dim), 0, dim - 1);

    int index = OCTREE_OFFSET[level] + (dim * dim * z + dim * y + x);
    
    return _OctreeBuffer[index];
}

bool IsInvalid(int level, int3 octreeId)
{
    int dim = OCTREE_DIM[level];
    if (octreeId.x >= dim || octreeId.y >= dim || octreeId.z >= dim || octreeId.x < 0 || octreeId.y < 0 || octreeId.z < 0)
        return true;

    return false;
}

float GetOctreeValueById(int level, int3 octreeId)
{
    int dim = OCTREE_DIM[level];

    int index = OCTREE_OFFSET[level] + (dim * dim * octreeId.z + dim * octreeId.y + octreeId.x);
    
    return _OctreeBuffer[index];
}

// Returns the octree id on the given level for given uvs [0, 1].
int3 GetOctreeId(int level, float3 uv)
{
    int dim = OCTREE_DIM[level];
    
    int x = clamp(floor(uv.x * dim), 0, dim - 1);
    int y = clamp(floor(uv.y * dim), 0, dim - 1);
    int z = clamp(floor(uv.z * dim), 0, dim - 1);
    
    return int3(x, y, z);
}

void RayOctree(int level, int3 currentId, float3 position, float3 dirOS, out int3 newId, out float3 newPos)
{
    // Get the number of cells in the current octree level
    int dim = OCTREE_DIM[level];
    
    // Get cell min and max in OS from the cell id [0, dim] => [-0.5, 0.5]
    float3 cellMinOS = BOX_MIN + (currentId / (float)dim);
    float3 cellMaxOS = BOX_MIN + ((currentId + int3(1, 1, 1)) / (float) dim);
    
    float3 cellBorder = 0;
    cellBorder.x = (dirOS.x > 0) ? cellMaxOS.x : cellMinOS.x;
    cellBorder.y = (dirOS.y > 0) ? cellMaxOS.y : cellMinOS.y;
    cellBorder.z = (dirOS.z > 0) ? cellMaxOS.z : cellMinOS.z;
    
    float3 invDir = 1 / dirOS;
    float3 t = (cellBorder - position) * invDir;
    
    // TODO control if t is positive
    
    if (t.x < t.y && t.x < t.z)
    {
        newId = currentId + sign(dirOS.x) * int3(1, 0, 0);
        newPos = position + dirOS * t.x;
    }
    else if (t.y < t.x && t.y < t.z)
    {
        newId = currentId + sign(dirOS.y) * int3(0, 1, 0);
        newPos = position + dirOS * t.y;
    }
    else if (t.z < t.y && t.z < t.x)
    {
        newId = currentId + sign(dirOS.z) * int3(0, 0, 1);
        newPos = position + dirOS * t.z;
    }
}

float3 RayOctreeBB(float3 uv, float level, float3 position, float3 dirOS)
{
    float dim = OCTREE_DIM[level];
    
    float3 cellMin = BOX_MIN + (floor(uv * dim) / dim);
    float3 cellMax = BOX_MIN + (ceil(uv * dim) / dim); // TODO case when uv * octreedim is exactly integer
    
    float3 invDir = 1 / dirOS;
    float3 tMin = (cellMin - position) * invDir;
    float3 tMax = (cellMax - position) * invDir;
    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    
    float3 hitPoint = position + dirOS * (tFar + SMALL_OFFSET); // Push the position inside the box
        
    return hitPoint;
}

#endif