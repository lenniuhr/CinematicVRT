#ifndef GAUSSIAN_BLUR_INCLUDED
#define GAUSSIAN_BLUR_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/DefaultInput.hlsl"

float4 GaussianBlurFragment(Varyings IN) : SV_TARGET
{
    return float4(0.2, 1.0, 0.5, 1);
}

#endif