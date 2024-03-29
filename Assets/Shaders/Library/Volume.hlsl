#ifndef VOLUME_INCLUDED
#define VOLUME_INCLUDED

#include "Assets/Shaders/Library/Common.hlsl"
#include "Assets/Shaders/Library/Tricubic.hlsl"
#include "Assets/Shaders/Library/RayTracingMaterial.hlsl"
#include "Assets/Shaders/Library/RayUtils.hlsl"

// Variables set in VolumeBoundingBox.cs

SAMPLER(sampler_point_clamp);
TEXTURE3D(_VolumeTex);  SAMPLER(sampler_VolumeTex);
TEXTURE3D(_GradientTex);  SAMPLER(sampler_GradientTex);

float3 _VolumeTexelSize;

float _VolumeClampRadius;
float3 _VolumePosition;
float3 _VolumeScale;
float3 _VolumeSpacing;

float4x4 _VolumeWorldToLocalMatrix;
float4x4 _VolumeLocalToWorldMatrix;
float4x4 _VolumeWorldToLocalNormalMatrix;

float3 _CutPosition;
float3 _CutNormal;

void ClampBounds(float3 uv, inout float density)
{
    // Clamp bounds
    float3 w = _VolumeTexelSize;
        
    if (uv.x < w.x || uv.y < w.y || uv.z < w.z)
    {
        float3 edge = InverseLerp(w, 0.0, uv);
        density = lerp(density, -1000, VectorMax(edge));
    }
    if (uv.x > 1.0 - w.x || uv.y > 1.0 - w.y || uv.z > 1.0 - w.z)
    {
        float3 edge = InverseLerp(1.0 - w, 1.0, uv);
        density = lerp(density, -1000, VectorMax(edge));
    }
    
    // Clamp plane
#ifdef CUTTING_PLANE
    
    float3 plainPos = _CutPosition;
    float3 plainNormal = normalize(_CutNormal);
    
    float c = plainNormal.x * plainPos.x + plainNormal.y * plainPos.y + plainNormal.z * plainPos.z;
    
    float3 pos = mul(_VolumeLocalToWorldMatrix, float4(VolumeCoordsToOS(uv), 1)).xyz;
    
    float r = (c - plainNormal.x * pos.x - plainNormal.y * pos.y - plainNormal.z * pos.z)
    / (plainNormal.x * plainNormal.x + plainNormal.y * plainNormal.y + plainNormal.z * plainNormal.z);
    
    // Koordinatenform: (n1x1, n2x2, n3x3) = c
    
    // Gerade: g = (pos) + r * (normal)
    
    // Setze gerade in E ein
    
    // n1 * (pos.x + r * normal.x) + n2 * (pos.y + r * normal.y) + n3 * (pos.z + r * normal.z) = c
    // n1*pos.x + n1*r*normal.x + n2*pos.y + n2*r*normal.y + n3*pos.z + n3*r*normal.z = c
    // n1*r*normal.x + n2*r*normal.y + n3*r*normal.z = c - n1*pos.x - n2*pos.y - n3*pos.z
    // r * (n1*normal.x + n2*normal.y + n3*normal.z) = c - n1*pos.x - n2*pos.y - n3*pos.z
    // r = c - n1*pos.x - n2*pos.y - n3*pos.z / (n1*normal.x + n2*normal.y + n3*normal.z)
    
    if (r < 0)
    {
        density = -1000;
    }
#endif
    
    // Clamp cylinder
    float x = VectorMax(w);
    
    if (distance(uv.xy, float2(0.5, 0.5)) > _VolumeClampRadius)
    {
        density = lerp(density, -1000, InverseLerp(_VolumeClampRadius, _VolumeClampRadius + x, distance(uv.xy, float2(0.5, 0.5))));
    }
}

void SampleGradientAndNormal(float3 uv, out float3 gradient, out float3 normal)
{
    float3 w = _VolumeTexelSize;
    
    float densityRange = 2000 - (-1000);
    
    float3 uvX1 = uv + w * float3(1, 0, 0);
    float3 uvX2 = uv + w * float3(-1, 0, 0);
    float3 uvY1 = uv + w * float3(0, 1, 0);
    float3 uvY2 = uv + w * float3(0, -1, 0);
    float3 uvZ1 = uv + w * float3(0, 0, 1);
    float3 uvZ2 = uv + w * float3(0, 0, -1);
    
    float x1 = SAMPLE_TEXTURE3D_LOD(_VolumeTex, sampler_VolumeTex, uvX1, 0).r;
    float x2 = SAMPLE_TEXTURE3D_LOD(_VolumeTex, sampler_VolumeTex, uvX2, 0).r;
    float y1 = SAMPLE_TEXTURE3D_LOD(_VolumeTex, sampler_VolumeTex, uvY1, 0).r;
    float y2 = SAMPLE_TEXTURE3D_LOD(_VolumeTex, sampler_VolumeTex, uvY2, 0).r;
    float z1 = SAMPLE_TEXTURE3D_LOD(_VolumeTex, sampler_VolumeTex, uvZ1, 0).r;
    float z2 = SAMPLE_TEXTURE3D_LOD(_VolumeTex, sampler_VolumeTex, uvZ2, 0).r;
    
    gradient = float3(
    (x2 - x1) / (densityRange * _VolumeSpacing.x),
    (y2 - y1) / (densityRange * _VolumeSpacing.y),
    (z2 - z1) / (densityRange * _VolumeSpacing.z)
    );
    
    ClampBounds(uvX1, x1);
    ClampBounds(uvX2, x2);
    ClampBounds(uvY1, y1);
    ClampBounds(uvY2, y2);
    ClampBounds(uvZ1, z1);
    ClampBounds(uvZ2, z2);
    
    normal = normalize(float3(
    (x2 - x1) / (densityRange * _VolumeSpacing.x),
    (y2 - y1) / (densityRange * _VolumeSpacing.y),
    (z2 - z1) / (densityRange * _VolumeSpacing.z)
    ));
}

float SampleDensity(float3 uv)
{
#ifdef TRICUBIC_SAMPLING
    float3 dim = 1.0 / _VolumeTexelSize;
    float density = tex3DTricubic(_VolumeTex, sampler_VolumeTex, uv, dim);
#else
    float density = SAMPLE_TEXTURE3D_LOD(_VolumeTex, sampler_VolumeTex, uv, 0).r;
#endif
    
    ClampBounds(uv, density);
    
    return density;
}

float SampleDensityPoint(float3 uv)
{
    float density = SAMPLE_TEXTURE3D_LOD(_VolumeTex, sampler_point_clamp, uv, 0).r;
    
    ClampBounds(uv, density);
    
    return density;
}

float3 SampleGradient(float3 uv)
{
    if (uv.x < 0.0 || uv.y < 0.0 || uv.z < 0.0 || uv.x > 1.0 || uv.y > 1.0 || uv.z > 1.0)
    {
        return 0;
    }
    
    //float3 gradient = tex3DTricubic(_GradientTex, sampler_GradientTex, uv, float3(512, 512, 460)).xyz * 2 - 1;
    float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
    return gradient;
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
    float3 w = _VolumeTexelSize;
    
    float densityRange = 2000 - (-1000);
    
    float x1 = SampleDensity(uv + w * float3(1, 0, 0));
    float x2 = SampleDensity(uv + w * float3(-1, 0, 0));
    float y1 = SampleDensity(uv + w * float3(0, 1, 0));
    float y2 = SampleDensity(uv + w * float3(0, -1, 0));
    float z1 = SampleDensity(uv + w * float3(0, 0, 1));
    float z2 = SampleDensity(uv + w * float3(0, 0, -1));
    
    float3 gradient = float3((x2 - x1) / densityRange, (y2 - y1) / densityRange, (z2 - z1) / densityRange);
    return gradient;
}

#endif