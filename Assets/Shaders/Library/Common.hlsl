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

float VectorMax(float3 v)
{
    return max(max(v.x, v.y), v.z);
}

bool Equals(int3 a, int3 b)
{
    return a.x == b.x && a.y == b.y && a.z == b.z;
}

float3x3 AngleAxis3x3(float angle, float3 axis)
{
    float c, s;
    sincos(angle, s, c);

    float t = 1 - c;
    float x = axis.x;
    float y = axis.y;
    float z = axis.z;

    return float3x3(
        t * x * x + c, t * x * y - s * z, t * x * z + s * y,
        t * x * y + s * z, t * y * y + c, t * y * z - s * x,
        t * x * z - s * y, t * y * z + s * x, t * z * z + c
    );
}

#endif