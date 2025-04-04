#ifndef TONEMAPPING_INCLUDED
#define TONEMAPPING_INCLUDED

TEXTURE2D(_SourceTex);      SAMPLER(sampler_point_clamp);
TEXTURE2D(_CopyTex);

float _WhiteThreshold;
float _ShoulderStrength;
float _LinearStrength;
float _LinearAngle;
float _ToeStrength;
float _ToeNumerator;
float _ToeDenominator;
float _LinearWhite;

float4 Uncharted2Tonemapping(float A, float B, float C, float D, float E, float F, float4 x)
{
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

float4 ToneMappingFragment(Varyings IN) : SV_TARGET
{
    float4 color = SAMPLE_TEXTURE2D(_SourceTex, sampler_point_clamp, IN.uv);
    
    if (color.r >= _WhiteThreshold && color.g >= _WhiteThreshold && color.b >= _WhiteThreshold)
        return color;
    
    float A = pow(_ShoulderStrength, 1 / 2.2); // 0.5
    float B = pow(_LinearStrength, 1 / 2.2); // 0.58
    float C = pow(_LinearAngle, 1 / 2.2); // 0.35
    float D = pow(_ToeStrength, 1 / 2.2); // 0.48
    float E = pow(_ToeNumerator, 1 / 2.2); // 0.12
    float F = pow(_ToeDenominator, 1 / 2.2); // 0.58
    float linearWhite = pow(_LinearWhite, 1 / 2.2); // 1.65
    
    float4 finalColor = Uncharted2Tonemapping(A, B, C, D, E, F, color) * linearWhite;
    return finalColor;
}

float4 CopyFragment(Varyings IN) : SV_TARGET
{
    return SAMPLE_TEXTURE2D(_CopyTex, sampler_point_clamp, IN.uv);
}

#endif