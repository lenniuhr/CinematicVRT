#ifndef BLUR_3D_INCLUDED
#define BLUR_3D_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/DefaultInput.hlsl"

TEXTURE2D(_MainTex);    SAMPLER(sampler_point_clamp);
float4 _MainTex_TexelSize;
int _KernelRadius;
float _Sigma;
float _SigmaR;

TEXTURE3D(_VolumeTex);    SAMPLER(sampler_VolumeTex);

float Gauss(int x, int y)
{
    return exp(-(x * x + y * y) / (2 * _Sigma * _Sigma));
}

float3 GaussSimilarity(float3 center, float3 value)
{
    return exp(-abs(center - value) / (2 * _SigmaR * _SigmaR));
}

float3 GaussianBlur(float3 uv)
{
    float3 color = 0;
    float totalWeight = 0;
    
    for (int x = -_KernelRadius; x <= _KernelRadius; x++)
    {
        for (int y = -_KernelRadius; y <= _KernelRadius; y++)
        {
            float3 nUV = uv + _MainTex_TexelSize.xyz * int3(x, y, 0);
            
            if (nUV.x > 0 && nUV.y > 0 && nUV.x < 1 && nUV.y < 1)
            {
                float3 value = SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, nUV).rgb;
            
                float weight = Gauss(x, y);
            
                color += weight * value;
                totalWeight += weight;
            }
        }
    }

    return color / totalWeight;
}

float4 GaussianBlur3DFragment(Varyings IN) : SV_TARGET
{
    //return pow(SAMPLE_TEXTURE3D(_MainTex, sampler_point_clamp, float3(IN.uv, 0)), 2.2);
    
    return SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, float3(IN.uv, 0));
    
    return SAMPLE_TEXTURE2D(_MainTex, sampler_point_clamp, IN.uv);
    
    float3 color = GaussianBlur(float3(IN.uv, 0));
    return float4(color, 1);
}

float4 BilateralBlur3DFragment(Varyings IN) : SV_TARGET
{
    float3 color = GaussianBlur(float3(IN.uv, 0));
    return float4(color, 1);
}




#endif