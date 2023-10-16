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

#endif