#ifndef RAY_UTILS_INCLUDED
#define RAY_UTILS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/Library/RayTracingMaterial.hlsl"

#define BOX_MIN float3(-0.5, -0.5, -0.5)
#define BOX_MAX float3(0.5, 0.5, 0.5)
#define SMALL_OFFSET 0.0000

float3 _ViewParams;
float4x4 _CamLocalToWorldMatrix;

struct Ray
{
    float3 originOS;
    float3 dirOS;
    float3 dirWS;
    int type;
};

struct HitInfo
{
    bool didHit;
    float dist;
    float3 hitPointOS;
    float3 normalOS;
    float3 gradient;
    RayTracingMaterial material;
    bool debug;
};

bool InVolumeBoundsOS(float3 positionOS)
{
    return positionOS.x > BOX_MIN.x && positionOS.y > BOX_MIN.y && positionOS.z > BOX_MIN.z 
    && positionOS.x < BOX_MAX.x && positionOS.y < BOX_MAX.y && positionOS.z < BOX_MAX.z;
}

// Returns the volume coords in range [0, 1].
float3 GetVolumeCoords(float3 positionOS)
{
    return InverseLerp(BOX_MIN, BOX_MAX, positionOS);
}

float3 VolumeCoordsToOS(float3 uv)
{
    return lerp(BOX_MIN, BOX_MAX, uv);
}

Ray GetRay(float2 screenUV, float4x4 worldToObjectMat, float2 pixelOffset)
{
    float3 viewPointLocal = float3(screenUV - 0.5 + pixelOffset, 1) * _ViewParams;
    float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1)).xyz;
    
    float3 originWS = _WorldSpaceCameraPos;
    float3 dirWS = normalize(viewPoint - originWS);
    
    Ray ray;
    ray.originOS = mul(worldToObjectMat, float4(originWS, 1)).xyz;
    ray.dirOS = normalize(mul((float3x3) worldToObjectMat, dirWS));
    ray.dirWS = dirWS;
    ray.type = 0;
    return ray;
}

Ray GetRay(float2 screenUV, float4x4 worldToObjectMat, float2 pixelOffset, float2 jitter)
{
    float3 viewPointLocal = float3(screenUV - 0.5 + pixelOffset, 1) * _ViewParams;
    float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1)).xyz;
    
    // Jitter ray origin
    float3 camRight = _CamLocalToWorldMatrix._m00_m10_m20;
    float3 camUp = _CamLocalToWorldMatrix._m01_m11_m21;
    float3 originWS = _WorldSpaceCameraPos + camRight * jitter.x + camUp * jitter.y;
    float3 dirWS = normalize(viewPoint - originWS);
    
    Ray ray;
    ray.originOS = mul(worldToObjectMat, float4(originWS, 1)).xyz;
    ray.dirOS = normalize(mul((float3x3) worldToObjectMat, dirWS));
    ray.dirWS = dirWS;
    ray.type = 0;
    return ray;
}

Ray GetRay(float2 screenUV, float4x4 worldToObjectMat)
{
    return GetRay(screenUV, worldToObjectMat, float2(0, 0));
}

bool RayBoundingBoxOS(Ray ray, out float3 hitPoint)
{
    // Return hit when ray origin is in bounds
    if (InVolumeBoundsOS(ray.originOS))
    {
        hitPoint = ray.originOS;
        return true;
    }
    
    float3 invDir = 1 / ray.dirOS;
    float3 tMin = (BOX_MIN - ray.originOS) * invDir;
    float3 tMax = (BOX_MAX - ray.originOS) * invDir;
    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    
    if (tNear >= 0)
    {
        bool didHit = tNear <= tFar;
        hitPoint = ray.originOS + ray.dirOS * (tNear + SMALL_OFFSET); // Push the position inside the box
        return didHit;
    }
    return false;
};

#endif