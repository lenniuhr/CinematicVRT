#ifndef DEFAULT_INPUT_INCLUDED
#define DEFAULT_INPUT_INCLUDED

struct Attributes
{
    float4 positionOS   : POSITION;
    float2 texcoord : TEXCOORD0;
};

struct Varyings
{
    float4 positionHCS  : SV_POSITION;
    float2 uv : TEXCOORD0;
};

#endif