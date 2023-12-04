#ifndef ENVIRONMENT_INCLUDED
#define ENVIRONMENT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

TEXTURECUBE(_EnvironmentMap);       SAMPLER(sampler_EnvironmentMap);
TEXTURECUBE(_IrradianceMap);        SAMPLER(sampler_IrradianceMap);
TEXTURECUBE(_ReflectionMap);        SAMPLER(sampler_ReflectionMap);

float4 SampleEnvironment(float3 dirWS, int rayType)
{
    float4 skyData;
    if (rayType == 0) // From camera
    {
        skyData = SAMPLE_TEXTURECUBE(_EnvironmentMap, sampler_EnvironmentMap, dirWS);
        //skyData = 0;
    }
    else if (rayType == 1) // Diffuse bounce
    {
        skyData = SAMPLE_TEXTURECUBE(_IrradianceMap, sampler_IrradianceMap, dirWS);
    }
    else if (rayType == 2) // Specular bounce
    {
        skyData = SAMPLE_TEXTURECUBE(_ReflectionMap, sampler_ReflectionMap, dirWS);
    }
    
    //skyData = SAMPLE_TEXTURECUBE(_IrradianceMap, sampler_IrradianceMap, dirWS);
    //return saturate((dot(dirWS, float3(1, 0, 0)) - 0.5) * 2);
    
    //return 1;
    
    
    return skyData;
}

#endif