#ifndef BRDF_INCLUDED
#define BRDF_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/Shaders/Library/Common.hlsl"

#define kDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)

struct MyBRDFData
{
    half3 albedo;
    half3 diffuse;
    half3 specular;
    half reflectivity;
    half perceptualRoughness;
    half roughness;
    half roughness2;
    half grazingTerm;
    half normalizationTerm; // roughness * 4.0 + 2.0
    half roughness2MinusOne; // roughness^2 - 1.0
};

void InitializeBRDFData(half3 albedo, half smoothness, half metallic, out MyBRDFData outBRDFData)
{
    half oneMinusDielectricSpec = kDielectricSpec.a;
    oneMinusDielectricSpec = oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;

    half oneMinusReflectivity = oneMinusDielectricSpec;
    half reflectivity = half(1.0) - oneMinusReflectivity;
    half3 brdfDiffuse = albedo * oneMinusReflectivity;
    half3 brdfSpecular = lerp(kDieletricSpec.rgb, albedo, metallic);

    outBRDFData = (MyBRDFData) 0;
    outBRDFData.albedo = albedo;
    outBRDFData.diffuse = brdfDiffuse;
    outBRDFData.specular = brdfSpecular;
    outBRDFData.reflectivity = reflectivity;

    outBRDFData.perceptualRoughness = (1.0 - smoothness);
    outBRDFData.roughness = max(outBRDFData.perceptualRoughness * outBRDFData.perceptualRoughness, HALF_MIN_SQRT);
    outBRDFData.roughness2 = max(outBRDFData.roughness * outBRDFData.roughness, HALF_MIN);
    outBRDFData.grazingTerm = saturate(smoothness + reflectivity);
    outBRDFData.normalizationTerm = outBRDFData.roughness * half(4.0) + half(2.0);
    outBRDFData.roughness2MinusOne = outBRDFData.roughness2 - half(1.0);

}

float3 PBRLighting(half3 albedo, half smoothness, half metallic, float3 viewDirectionWS, float3 normalWS, half3 bakedGI)
{
    // Initalize brdf data
    MyBRDFData brdfData;
    InitializeBRDFData(albedo, smoothness, metallic, brdfData);
    // Global Illumination

    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half NoV = saturate(dot(normalWS, viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);

    half3 indirectDiffuse = bakedGI;

    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, half(1.0));

    // EnvironmentBRDF
    half3 c = indirectDiffuse * brdfData.diffuse;

    float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
    c += indirectSpecular * half3(surfaceReduction * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm));

    return c;
}

#endif