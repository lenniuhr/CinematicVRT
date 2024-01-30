#ifndef ENVIRONMENT_INCLUDED
#define ENVIRONMENT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/Library/Common.hlsl"

TEXTURECUBE(_EnvironmentMap);       SAMPLER(sampler_EnvironmentMap);
TEXTURECUBE(_IrradianceMap);        SAMPLER(sampler_IrradianceMap);
TEXTURECUBE(_ReflectionMap);        SAMPLER(sampler_ReflectionMap);

float4 _EnvironmentColor;
bool _ShowEnvironment;

float _EnvironmentRotation;

float4 SampleEnvironment(float3 dirWS, int rayType)
{
    float3x3 rotation = AngleAxis3x3(_EnvironmentRotation, float3(0, 1, 0));
    dirWS = mul(rotation, dirWS);
    
    float4 skyData;
    if (rayType == 0) // From camera
    {
        //skyData = SAMPLE_TEXTURECUBE_LOD(_EnvironmentMap, sampler_EnvironmentMap, dirWS, 0);
        skyData = SAMPLE_TEXTURECUBE_LOD(_ReflectionMap, sampler_ReflectionMap, dirWS, 0);
        
        // Clamp to prevent fireflys when a ray randomly passes through the volume
        skyData = clamp(skyData, 0, 2);

        if (!_ShowEnvironment)
        {
            skyData = _EnvironmentColor;
            return skyData;
        }
    }
    else if (rayType == 1) // Diffuse bounce
    {
        skyData = SAMPLE_TEXTURECUBE_LOD(_IrradianceMap, sampler_IrradianceMap, dirWS, 0);
    }
    else if (rayType == 2) // Specular bounce
    {
        skyData = SAMPLE_TEXTURECUBE_LOD(_ReflectionMap, sampler_ReflectionMap, dirWS, 0);
    }
    
    //skyData = SAMPLE_TEXTURECUBE(_ReflectionMap, sampler_ReflectionMap, dirWS);
    //skyData = SAMPLE_TEXTURECUBE(_IrradianceMap, sampler_IrradianceMap, dirWS);
    
    //skyData = SAMPLE_TEXTURECUBE_LOD(_EnvironmentMap, sampler_EnvironmentMap, dirWS, 0);
    
    return skyData;
}

#endif