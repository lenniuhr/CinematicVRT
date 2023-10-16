#ifndef OCTREE_INCLUDED
#define OCTREE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/Library/OctreeUtils.hlsl"

StructuredBuffer<float> _OctreeBuffer;
int _OctreeLevel;
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

// Returns the octree id on the given level for given uvs [0, 1].
int3 GetOctreeId(int level, float3 uv)
{
    int dim = OCTREE_DIM[level];
    
    int x = clamp(floor(uv.x * dim), 0, dim - 1);
    int y = clamp(floor(uv.y * dim), 0, dim - 1);
    int z = clamp(floor(uv.z * dim), 0, dim - 1);
    
    return int3(x, y, z);
}

#endif