#ifndef PHASE_FUNCTION_INCLUDED
#define PHASE_FUNCTION_INCLUDED

#include "Assets/Shaders/Library/Random.hlsl"

void CoordinateSystem(float3 v1, out float3 v2, out float3 v3)
{
    if (abs(v1.x) > abs(v1.y))
    {
        v2 = float3(-v1.z, 0, v1.x) / sqrt(v1.x * v1.x + v1.z * v1.z);
    }
    else
    {
        v2 = float3(0, v1.z, -v1.y) / sqrt(v1.y * v1.y + v1.z * v1.z);
    }
    v3 = cross(v1, v2);
}

float3 SphericalDirection(float sinTheta, float cosTheta, float phi, float3 x, float3 y, float3 z)
{
    return sinTheta * cos(phi) * x + sinTheta * sin(phi) * y + cosTheta * z;
}

// Samples the Henyey-Greenstein phase function and returns a outgoing direction.
// direction: the ingoing direction.
// g: the scattering coefficient g in range [-1, 1].
// rngState: the random state
float3 SamplePhaseFunctionHG(float3 direction, float g, inout uint rngState)
{
    float cosTheta;
    if (abs(g) < 1e-3)
    {
        cosTheta = 1.0 - 2.0 * RandomValue(rngState);
    }
    else
    {
        float sqrTerm = (1.0 - g * g) / (1.0 - g + 2.0 * g * RandomValue(rngState));
        cosTheta = (1.0 + g * g - sqrTerm * sqrTerm) / (2.0 * g);
    }
    
    float sinTheta = sqrt(max(0.0, 1.0 - cosTheta * cosTheta));
    float phi = 2.0 * PI * RandomValue(rngState);
    
    
    float3 v1, v2;
    CoordinateSystem(direction, v1, v2);
    
    return SphericalDirection(sinTheta, cosTheta, phi, v1, v2, direction);
}

#endif