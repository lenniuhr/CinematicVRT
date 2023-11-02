#ifndef CLASSIFICATION_INCLUDED
#define CLASSIFICATION_INCLUDED

#include "Assets/Shaders/Library/Common.hlsl"

struct DensityClass
{
    float min;
    float max;
    float gradientLimit;
    float weight;
    float4 color;
};

StructuredBuffer<DensityClass> _DensityClasses;

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
    return ((_DensityClasses[index].min + _DensityClasses[index].max) * 0.5 + 1000.0) / 3000.0;
}

half GetMin(int index)
{
    return (_DensityClasses[index].min + 1000.0) / 3000.0;
}

half GetMax(int index)
{
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
            //value = cos(distance01 * 3.1415) * 0.5 + 0.5;
            value = 1 - distance01;
        }
        return value;

    }
    return 0;
}

#endif