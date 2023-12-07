#ifndef OCTREE_INCLUDED
#define OCTREE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/Library/OctreeUtils.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/RayUtils.hlsl"

StructuredBuffer<float> _OctreeBuffer;

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

// Returns the octree id on the given level for given UVs [0, 1].
int3 GetOctreeId(int level, float3 uv)
{
    int dim = OCTREE_DIM[level];
    
    int x = clamp(floor(uv.x * dim), 0, dim - 1);
    int y = clamp(floor(uv.y * dim), 0, dim - 1);
    int z = clamp(floor(uv.z * dim), 0, dim - 1);
    
    return int3(x, y, z);
}

float3 GetOctreeNormal(int level, int3 octreeId, float3 uv)
{
    float dim = OCTREE_DIM[level];
    float3 innerBorder01 = (((float3) octreeId + float3(0.5, 0.5, 0.5)) / (float) dim);
    
    float3 distance = uv - innerBorder01;
    
    if (abs(distance.x) > abs(distance.y) && abs(distance.x) > abs(distance.z))
    {
        return sign(distance.x) * float3(1, 0, 0);
    }
    else if (abs(distance.y) > abs(distance.x) && abs(distance.y) > abs(distance.z))
    {
        return sign(distance.y) * float3(0, 1, 0);
    }
    else if (abs(distance.z) > abs(distance.x) && abs(distance.z) > abs(distance.y))
    {
        return sign(distance.z) * float3(0, 0, 1);
    }
    return float3(0, 0, 0);
}

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

void IncreaseOctreeLevel(inout int level, inout int3 octreeId, float3 uv, float threshold, int maxLevel = 7)
{
    while (level < maxLevel)
    {
        octreeId = GetChildOctreeId(level, octreeId, uv);
        level++;
        
        // When value is lesser than threshold, stay on this level
        float value = GetOctreeValueById(level, octreeId);
        if (value <= threshold)
        {
            break;
        }
    }
}

void ReduceOctreeLevel(inout int level, inout int3 octreeId, float threshold)
{
    for (int p = 0; p < 8; p++)
    {
        if (level <= 0)
            break;
                    
        int3 parentId = floor(octreeId / 2);
        float parentValue = GetOctreeValueById(level - 1, parentId);
        if (parentValue <= threshold)
        {
            level--;
            octreeId = parentId;
            parentId = floor(octreeId / 2);
        }
        else
        {
            break;
        }
    }
}

float GetCellSize(int level)
{
    return 1.0 / OCTREE_DIM[level];
}

float RayOctreeT(int level, int3 currentId, float3 position, float3 dirOS, out int3 newId, out float3 newPos)
{
    // Get the number of cells in the current octree level
    int dim = OCTREE_DIM[level];
    
    // Get cell min and max in OS from the cell id [0, dim] => [-0.5, 0.5]
    float3 cellMinOS = BOX_MIN + (currentId / (float) dim);
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
        return t.x;
    }
    else if (t.y < t.x && t.y < t.z)
    {
        newId = currentId + sign(dirOS.y) * int3(0, 1, 0);
        newPos = position + dirOS * t.y;
        return t.y;
    }
    else if (t.z < t.y && t.z < t.x)
    {
        newId = currentId + sign(dirOS.z) * int3(0, 0, 1);
        newPos = position + dirOS * t.z;
        return t.z;
    }
    return t.x;
}

void RayOctree(int level, int3 currentId, float3 position, float3 dirOS, out int3 newId, out float3 newPos)
{
    // Get the number of cells in the current octree level
    int dim = OCTREE_DIM[level];
    
    // Get cell min and max in OS from the cell id [0, dim] => [-0.5, 0.5]
    float3 cellMinOS = BOX_MIN + (currentId / (float) dim);
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

// Checks, if the given octree box is valid for the direction, and can be traversed by follwing the ray direction.
bool IsValid(float3 position, float3 dirOS, int level, inout int3 id)
{
    // Get the number of cells in the current octree level
    int dim = OCTREE_DIM[level];
    
    // Get cell min and max in OS from the cell id [0, dim] => [-0.5, 0.5]
    float3 cellMinOS = BOX_MIN + (id / (float) dim);
    float3 cellMaxOS = BOX_MIN + ((id + int3(1, 1, 1)) / (float) dim);
    
    float3 cellBorder = 0;
    cellBorder.x = (dirOS.x > 0) ? cellMaxOS.x : cellMinOS.x;
    cellBorder.y = (dirOS.y > 0) ? cellMaxOS.y : cellMinOS.y;
    cellBorder.z = (dirOS.z > 0) ? cellMaxOS.z : cellMinOS.z;
    
    float3 invDir = 1 / dirOS;
    float3 t = (cellBorder - position) * invDir;
    
    if (t.x < 0 || t.y < 0 || t.z < 0)
        return false;
    
    return true;
}

bool RayOctree(float3 dirOS, int level, inout int3 id, inout float3 position)
{
    // Get the number of cells in the current octree level
    int dim = OCTREE_DIM[level];
    
    // Get cell min and max in OS from the cell id [0, dim] => [-0.5, 0.5]
    float3 cellMinOS = BOX_MIN + (id / (float) dim);
    float3 cellMaxOS = BOX_MIN + ((id + int3(1, 1, 1)) / (float) dim);
    
    float3 cellBorder = 0;
    cellBorder.x = (dirOS.x > 0) ? cellMaxOS.x : cellMinOS.x;
    cellBorder.y = (dirOS.y > 0) ? cellMaxOS.y : cellMinOS.y;
    cellBorder.z = (dirOS.z > 0) ? cellMaxOS.z : cellMinOS.z;
    
    float3 invDir = 1 / dirOS;
    float3 t = (cellBorder - position) * invDir;
    
    // TODO control if t is positive
    if (t.x < t.y && t.x < t.z)
    {
        id = id + sign(dirOS.x) * int3(1, 0, 0);
        position = position + dirOS * t.x;
    }
    else if (t.y < t.x && t.y < t.z)
    {
        id = id + sign(dirOS.y) * int3(0, 1, 0);
        position = position + dirOS * t.y;
    }
    else if (t.z < t.y && t.z < t.x)
    {
        id = id + sign(dirOS.z) * int3(0, 0, 1);
        position = position + dirOS * t.z;
    }
    
    
    
    if (t.x < 0 || t.y < 0 || t.z < 0)
        return false;
    
    return true;
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