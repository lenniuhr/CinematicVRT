#ifndef CLASSIFICATION_INCLUDED
#define CLASSIFICATION_INCLUDED

#include "Assets/Shaders/Library/Common.hlsl"
#include "Assets/Shaders/Library/RayTracingMaterial.hlsl"

struct DensityClass
{
    float min;
    float max;
    float gradientLimit;
    float weight;
    float4 color;
    float metallicness;
    float roughness;
    float reflectance;
};

StructuredBuffer<DensityClass> _DensityClasses;

RayTracingMaterial GetMaterial(float4 uv)
{
    RayTracingMaterial material = (RayTracingMaterial)0;
    
    if (length(uv) == 0)
        return material;
    
    float4 normalizedUV = uv / (uv.x + uv.y + uv.z + uv.w);
    
    //material.color = normalizedUV.x * _DensityClasses[0].color + normalizedUV.y * _DensityClasses[1].color + normalizedUV.z * _DensityClasses[2].color;
    material.metallic = normalizedUV.x * _DensityClasses[0].metallicness + normalizedUV.y * _DensityClasses[1].metallicness + normalizedUV.z * _DensityClasses[2].metallicness;
    material.roughness = normalizedUV.x * _DensityClasses[0].roughness + normalizedUV.y * _DensityClasses[1].roughness + normalizedUV.z * _DensityClasses[2].roughness;
    material.reflectance = normalizedUV.x * _DensityClasses[0].reflectance + normalizedUV.y * _DensityClasses[1].reflectance + normalizedUV.z * _DensityClasses[2].reflectance;
    
    return material;
}

float4 GetClassColor(float4 uv)
{
    if (length(uv) == 0)
        return 0;
    
    float4 normalizedUV = uv / (uv.x + uv.y + uv.z + uv.w);

    float4 mixedColor = normalizedUV.x * _DensityClasses[0].color + normalizedUV.y * _DensityClasses[1].color + normalizedUV.z * _DensityClasses[2].color;
    
    
    return mixedColor;
}

bool InDensityRange(float density, int index)
{
    return (density > _DensityClasses[index].min && density < _DensityClasses[index].max);
    
    float min = (_DensityClasses[index].min + 1000.0) / 3000.0;
    float max = (_DensityClasses[index].max + 1000.0) / 3000.0;
    
    return (density > min && density < max);
}

bool InDensityRangeMinMax(float min, float max, float density)
{
    return (density > min && density < max);
}

float GetCenter(int index)
{
    return (_DensityClasses[index].min + _DensityClasses[index].max) * 0.5;
    
    return ((_DensityClasses[index].min + _DensityClasses[index].max) * 0.5 + 1000.0) / 3000.0;
}

half GetMin(int index)
{
    return _DensityClasses[index].min;
    
    return (_DensityClasses[index].min + 1000.0) / 3000.0;
}

half GetMax(int index)
{
    return _DensityClasses[index].max;
    
    return (_DensityClasses[index].max + 1000.0) / 3000.0;
}

float GetClassDensity(float density, int id)
{
    
    if (InDensityRange(density, id))
    {
        
        float d = (GetMax(id) - GetMin(id)) * 0.5;
        
        float x = abs(density - GetCenter(id));
        
        float distance01 = saturate(x / d);
        
        float width = _DensityClasses[id].weight;
        
        float value;
        if (distance01 < width)
        {
            value = 1;
        }
        else
        {
            distance01 = (distance01 - width) / (1 - width);
            value = 1 - distance01;
        }
        return value;

    }
    return 0;
}

float4 GetGradientLimits()
{
    float4 gradientLimits = 0;
    gradientLimits.r = _DensityClasses[0].gradientLimit;
    gradientLimits.g = _DensityClasses[1].gradientLimit;
    gradientLimits.b = _DensityClasses[2].gradientLimit;
    return gradientLimits;
}

float4 GetClassColorFromDensity(float density, float3 gradient)
{
    float4 gradientLimits = GetGradientLimits();
    float4 w = InverseLerpVector4(gradientLimits, 0, length(gradient));
    
    w = 1;
    
    float4 uv = 0;
    uv.r = GetClassDensity(density, 0) * w.r;
    uv.g = GetClassDensity(density, 1) * w.g;
    uv.b = GetClassDensity(density, 2) * w.b;
    
    return GetClassColor(uv);
}


#endif