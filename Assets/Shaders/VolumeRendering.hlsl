#ifndef VOLUME_RENDERING_INCLUDED
#define VOLUME_RENDERING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/DefaultInput.hlsl"

float3 _ViewParams;
float4x4 _CamLocalToWorldMatrix;

TEXTURE3D(_VolumeTex);  SAMPLER(sampler_VolumeTex);
float3 _VolumePosition;
float3 _VolumeScale;

struct Ray
{
    float3 origin;
    float3 dir;
};

struct HitInfo
{
    bool didHit;
    float3 hitPoint;
};

HitInfo RayBoundingBox(Ray ray, float3 boxMin, float3 boxMax)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float3 invDir = 1 / ray.dir;
    float3 tMin = (boxMin - ray.origin) * invDir;
    float3 tMax = (boxMax - ray.origin) * invDir;
    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    
    if (tNear >= 0)
    {
        hitInfo.didHit = tNear <= tFar;
        hitInfo.hitPoint = ray.origin + ray.dir * tNear;
    }
    
    return hitInfo;
};

float4 VolumeRenderingFragment(Varyings IN) : SV_TARGET
{
    float3 viewPointLocal = float3(IN.uv - 0.5, 1) * _ViewParams;
    float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1)).xyz;
    
    Ray ray;
    ray.origin = _WorldSpaceCameraPos;
    ray.dir = normalize(viewPoint - ray.origin);
    
    return SAMPLE_TEXTURE3D_LOD(_VolumeTex, sampler_VolumeTex, float3(IN.uv, 0), 8);
    
    float3 boxMin = _VolumePosition - _VolumeScale / 2.0;
    float3 boxMax = _VolumePosition + _VolumeScale / 2.0;
    HitInfo hit = RayBoundingBox(ray, boxMin, boxMax);

    if (hit.didHit)
    {
        return float4(1, 1, 1, 1);
    }
    return float4(0,0,0,0);
}

#endif