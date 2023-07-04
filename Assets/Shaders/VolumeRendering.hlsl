#ifndef VOLUME_RENDERING_INCLUDED
#define VOLUME_RENDERING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/DefaultInput.hlsl"

float3 _ViewParams;
float4x4 _CamLocalToWorldMatrix;

TEXTURE3D(_VolumeTex);  SAMPLER(sampler_VolumeTex);
float3 _VolumePosition;
float3 _VolumeScale;

float _StepSize;
float _NormalOffset;

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

float InverseLerp(float from, float to, float value)
{
    return saturate((value - from) / (to - from));
}

float3 InverseLerp(float3 from, float3 to, float3 value)
{
    return saturate((value - from) / (to - from));
}

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

float3 GetVolumeCoords(float3 positionWS)
{
    float3 boxMin = _VolumePosition - _VolumeScale / 2.0;
    float3 boxMax = _VolumePosition + _VolumeScale / 2.0;
    return InverseLerp(boxMin, boxMax, positionWS);
}

bool InVolumeBounds(float3 positionWS)
{
    float3 boxMin = _VolumePosition - _VolumeScale / 2.0;
    float3 boxMax = _VolumePosition + _VolumeScale / 2.0;
    return positionWS.x > boxMin.x && positionWS.y > boxMin.y && positionWS.z > boxMin.z 
    && positionWS.x < boxMax.x && positionWS.y < boxMax.y && positionWS.z < boxMax.z;
}

float SampleDensity(float3 uv)
{
    if (uv.x < 0.0 || uv.y < 0.0 || uv.z < 0.0 || uv.x > 1.0 || uv.y > 1.0 || uv.z > 1.0)
    {
        return 0;
    }
    return SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, uv).r;
}

float GetBlurredDensity(float3 uv)
{
    float offsetXY = 1 / 512.0;
    
    float3 rightUV = uv + float3(offsetXY, 0, 0);
    float3 leftUV = uv + float3(-offsetXY, 0, 0);
    float3 topUV = uv + float3(0, offsetXY, 0);
    float3 bottomUV = uv + float3(0, -offsetXY, 0);
    
    float3 rightTopUV = uv + float3(offsetXY, offsetXY, 0);
    float3 leftTopUV = uv + float3(-offsetXY, offsetXY, 0);
    float3 rightBottomUV = uv + float3(offsetXY, -offsetXY, 0);
    float3 leftBottomUV = uv + float3(-offsetXY, -offsetXY, 0);
    
    float value = SampleDensity(uv);
    
    float rightValue = SampleDensity(rightUV);
    float leftValue = SampleDensity(leftUV);
    float topValue = SampleDensity(topUV);
    float bottomValue = SampleDensity(bottomUV);
    
    float rightTopValue = SampleDensity(rightTopUV);
    float leftTopValue = SampleDensity(leftTopUV);
    float rightBottomValue = SampleDensity(rightBottomUV);
    float leftBottomValue = SampleDensity(leftBottomUV);
    
    float gaussian = (1 / 16.0) * (4 * value + 2 * rightValue + 2 * leftValue + 2 * topValue + 2 * bottomValue
    + rightTopValue + leftTopValue + rightBottomValue + leftBottomValue);

    return gaussian;
}

float3 ComputeNormal(float3 uv)
{
    float offsetXY = 1 * _NormalOffset / 512.0;
    float offsetZ = 1 * _NormalOffset / 105.0;
    
    float3 rightUV = uv + float3(offsetXY, 0, 0);
    float3 leftUV = uv + float3(-offsetXY, 0, 0);
    float3 topUV = uv + float3(0, offsetXY, 0);
    float3 bottomUV = uv + float3(0, -offsetXY, 0);
    float3 frontUV = uv + float3(0, 0, offsetZ);
    float3 backUV = uv + float3(0, 0, -offsetZ);
    
    float value = SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, uv).r;
    
    float rightValue = SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, rightUV).r;
    float leftValue = SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, leftUV).r;
    float topValue = SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, topUV).r;
    float bottomValue = SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, bottomUV).r;
    float frontValue = SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, frontUV).r;
    float backValue = SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, backUV).r;
    
    /*float value = GetBlurredDensity(uv);
    
    float rightValue = GetBlurredDensity(rightUV);
    float leftValue = GetBlurredDensity(leftUV);
    float topValue = GetBlurredDensity(topUV);
    float bottomValue = GetBlurredDensity(bottomUV);
    float frontValue = GetBlurredDensity(frontUV);
    float backValue = GetBlurredDensity(backUV);*/
    

    float gx = leftValue - rightValue;
    float gy = bottomValue - topValue;
    float gz = backValue - frontValue;

    return normalize(float3(gx, gy, gz));
}

float4 RayMarchVolume(float3 position, float3 direction)
{
    float3 step = direction * _StepSize;
    
    [loop]
    for (int i = 0; i < 720; i++)
    {
        position += step;
        
        if (!InVolumeBounds(position))
        {
            return 0;
        }
        
        float3 uv = GetVolumeCoords(position);
        
        float density = SampleDensity(uv);
        
        if (density > 0.2)
        {
            float3 normal = ComputeNormal(uv);
            return float4(normal, 1);
            
            //density = GetBlurredDensity(uv);
            
            return density;
        }
    }

    return 0;
}

float4 VolumeRenderingFragment(Varyings IN) : SV_TARGET
{
    float3 viewPointLocal = float3(IN.uv - 0.5, 1) * _ViewParams;
    float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1)).xyz;
    
    Ray ray;
    ray.origin = _WorldSpaceCameraPos;
    ray.dir = normalize(viewPoint - ray.origin);
    
    
    float3 boxMin = _VolumePosition - _VolumeScale / 2.0;
    float3 boxMax = _VolumePosition + _VolumeScale / 2.0;
    HitInfo hit = RayBoundingBox(ray, boxMin, boxMax);
    
    if (hit.didHit)
    {
        return RayMarchVolume(hit.hitPoint, ray.dir);
    }
    return float4(0.2, 0.5, 0.5, 1);
}

#endif