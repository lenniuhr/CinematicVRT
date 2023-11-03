#ifndef COMMON_INCLUDED
#define COMMON_INCLUDED

float InverseLerp(float from, float to, float value)
{
    return saturate((value - from) / (to - from));
}

float3 InverseLerp(float3 from, float3 to, float3 value)
{
    return saturate((value - from) / (to - from));
}

float4 InverseLerpVector4(float4 from, float4 to, float4 value)
{
    return saturate((value - from) / (to - from));
}

bool Equals(int3 a, int3 b)
{
    return a.x == b.x && a.y == b.y && a.z == b.z;
}

#endif