#ifndef VOLUME_INCLUDED
#define VOLUME_INCLUDED

#include "Assets/Shaders/Library/Common.hlsl"
#include "Assets/Shaders/Library/Tricubic.hlsl"
#include "Assets/Shaders/Library/RayTracingMaterial.hlsl"

#define BOX_MIN float3(-0.5, -0.5, -0.5)
#define BOX_MAX float3(0.5, 0.5, 0.5)
#define SMALL_OFFSET 0.0000

TEXTURE3D(_VolumeTex);  SAMPLER(sampler_VolumeTex);
TEXTURE3D(_GradientTex);  SAMPLER(sampler_GradientTex);
TEXTURE3D(_ClassifyTex);  SAMPLER(sampler_ClassifyTex);

float3 _VolumePosition;
float3 _VolumeScale;

float4x4 _VolumeWorldToLocalMatrix;
float4x4 _VolumeLocalToWorldMatrix;

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
    RayTracingMaterial material;
    bool debug;
};

float SampleDensity(float3 uv)
{
    if (uv.x < 0.0 || uv.y < 0.0 || uv.z < 0.0 || uv.x > 1.0 || uv.y > 1.0 || uv.z > 1.0)
    {
        return 0;
    }
    
    if (distance(uv.xy, float2(0.5, 0.5)) > 0.45)
    {
        return 0;
    }
    
    return tex3DTricubic(_VolumeTex, sampler_VolumeTex, uv, float3(512, 512, 460));
    //return SAMPLE_TEXTURE3D_LOD(_VolumeTex, sampler_VolumeTex, uv, 0).r;
}

float3 SampleNormal(float3 uv)
{
    if (uv.x < 0.0 || uv.y < 0.0 || uv.z < 0.0 || uv.x > 1.0 || uv.y > 1.0 || uv.z > 1.0)
    {
        return 0;
    }
    
    //float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
    float3 gradient = tex3DTricubic(_GradientTex, sampler_GradientTex, uv, float3(512, 512, 460)).xyz * 2 - 1;
    
    return normalize(gradient);
}

float3 CalculateGradient(float3 uv)
{
    float3 w = 1.0 / float3(512, 512, 460);
    
    float densityRange = 2500 - (-1000);
    
    float x1 = SampleDensity(uv + w * float3(1, 0, 0));
    float x2 = SampleDensity(uv + w * float3(-1, 0, 0));
    float y1 = SampleDensity(uv + w * float3(0, 1, 0));
    float y2 = SampleDensity(uv + w * float3(0, -1, 0));
    float z1 = SampleDensity(uv + w * float3(0, 0, 1));
    float z2 = SampleDensity(uv + w * float3(0, 0, -1));
    
    float3 gradient = float3((x2 - x1) / densityRange, (y2 - y1) / densityRange, (z2 - z1) / densityRange) * 0.5 + 0.5;
    return gradient;
}

float4 SampleClassification(float3 uv)
{
    if (uv.x < 0.0 || uv.y < 0.0 || uv.z < 0.0 || uv.x > 1.0 || uv.y > 1.0 || uv.z > 1.0)
    {
        return 0;
    }
    return SAMPLE_TEXTURE3D_LOD(_ClassifyTex, sampler_ClassifyTex, uv, 0);
    //return tex3DTricubic(_ClassifyTex, sampler_ClassifyTex, uv, float3(512, 512, 460));
}

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

Ray GetRay(float2 screenUV, float2 pixelOffset)
{
    float3 viewPointLocal = float3(screenUV - 0.5 + pixelOffset, 1) * _ViewParams;
    float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1)).xyz;
    
    float3 originWS = _WorldSpaceCameraPos;
    float3 dirWS = normalize(viewPoint - originWS);
    
    Ray ray;
    ray.originOS = mul(_VolumeWorldToLocalMatrix, float4(originWS, 1)).xyz;
    ray.dirOS = normalize(mul((float3x3) _VolumeWorldToLocalMatrix, dirWS));
    ray.dirWS = dirWS;
    ray.type = 0;
    return ray;
}

Ray GetRay(float2 screenUV)
{
    return GetRay(screenUV, float2(0, 0));
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