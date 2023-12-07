#ifndef PBR_INCLUDED
#define PBR_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/Library/Common.hlsl"

float3 fresnelSchlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float D_GGX(float NoH, float roughness)
{
    float alpha = roughness * roughness;
    float alpha2 = alpha * alpha;
    float NoH2 = NoH * NoH;
    float b = (NoH2 * (alpha2 - 1.0) + 1.0);
    return alpha2 / (PI * b * b);
}

float G1_GGX_Schlick(float NdotV, float roughness)
{
  //float r = roughness; // original
    float r = 0.5 + 0.5 * roughness; // Disney remapping
    float k = (r * r) / 2.0;
    float denom = max(NdotV, 0.001) * (1.0 - k) + k;
    return max(NdotV, 0.001) / denom;

}

float G_Smith(float NoV, float NoL, float roughness)
{
    float g1_l = G1_GGX_Schlick(NoL, roughness);
    float g1_v = G1_GGX_Schlick(NoV, roughness);
    return g1_l * g1_v;
}

float fresnelSchlick90(float cosTheta, float F0, float F90)
{
    return F0 + (F90 - F0) * pow(1.0 - cosTheta, 5.0);
}

float disneyDiffuseFactor(float NoV, float NoL, float VoH, float roughness)
{
    float alpha = roughness * roughness;
    float F90 = 0.5 + 2.0 * alpha * VoH * VoH;
    float F_in = fresnelSchlick90(NoL, 1.0, F90);
    float F_out = fresnelSchlick90(NoV, 1.0, F90);
    return F_in * F_out;
}

float3 MicrofacetBRDF(in float3 L, in float3 V, in float3 N,
              in float3 baseColor, in float metallicness,
              in float fresnelReflect, in float roughness)
{
     
    float3 H = normalize(V + L); // half vector

  // all required dot products
    float NoV = clamp(dot(N, V), 0.0, 1.0);
    float NoL = clamp(dot(N, L), 0.0, 1.0);
    float NoH = clamp(dot(N, H), 0.0, 1.0);
    float VoH = clamp(dot(V, H), 0.0, 1.0);
    
  // F0 for dielectics in range [0.0, 0.16] 
  // default FO is (0.16 * 0.5^2) = 0.04
    float3 f0 = 0.16 * (fresnelReflect * fresnelReflect) * float3(1, 1, 1);
  // in case of metals, baseColor contains F0
    f0 = lerp(f0, baseColor, metallicness);

  // specular microfacet (cook-torrance) BRDF
    float3 F = fresnelSchlick(VoH, f0);
    float D = D_GGX(NoH, roughness);
    float G = G_Smith(NoV, NoL, roughness);
    float3 spec = (F * D * G) / (4.0 * max(NoV, 0.001) * max(NoL, 0.001));
    
  // diffuse
    float3 notSpec = float3(1, 1, 1) - F; // if not specular, use as diffuse
    notSpec *= (1.0 - metallicness); // no diffuse for metals
    
    float disney = disneyDiffuseFactor(NoV, NoL, VoH, roughness);
    
    float3 diff = disney * baseColor / PI;
    
    return diff + spec;
}

float3x3 getNormalSpace(in float3 normal)
{
    float3 someVec = float3(1.0, 0.0, 0.0);
    float dd = dot(someVec, normal);
    float3 tangent = float3(0.0, 1.0, 0.0);
    if (1.0 - abs(dd) > 1e-6)
    {
        tangent = normalize(cross(someVec, normal));
    }
    float3 bitangent = cross(normal, tangent);
    
    return float3x3(
    tangent.x, bitangent.x, normal.x,
    tangent.y, bitangent.y, normal.y,
    tangent.z, bitangent.z, normal.z
    );
    return float3x3(tangent, bitangent, normal);
}

float3 SampleSpecularMicrofacetBRDF(in float3 V, in float3 N, in float3 baseColor, in float metallicness,
              in float fresnelReflect, in float roughness, in float3 random, out float3 nextFactor)
{
    
    // important sample GGX
    // pdf = D * cos(theta) * sin(theta)
    float a = roughness * roughness;
    float theta = acos(sqrt((1.0 - random.y) / (1.0 + (a * a - 1.0) * random.y)));
    float phi = 2.0 * PI * random.x;
    float3 localH = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
    
    //localH = float3(0, 0, 1);
    float3 H = mul(getNormalSpace(N), localH);
    
    //float3 L = reflect(-V, H);
    float3 L = reflect(-V, H);

    // all required dot products
    float NoV = clamp(dot(N, V), 0.0, 1.0);
    float NoL = clamp(dot(N, L), 0.0, 1.0);
    float NoH = clamp(dot(N, H), 0.0, 1.0);
    float VoH = clamp(dot(V, H), 0.0, 1.0);
    
    // F0 for dielectics in range [0.0, 0.16] 
    // default FO is (0.16 * 0.5^2) = 0.04
    float3 f0 = 0.16 * (fresnelReflect * fresnelReflect);
    // in case of metals, baseColor contains F0
    f0 = lerp(f0, baseColor, metallicness);
  
    // specular microfacet (cook-torrance) BRDF
    float3 F = fresnelSchlick(VoH, f0);
    float D = D_GGX(NoH, roughness);
    float G = G_Smith(NoV, NoL, roughness);
    nextFactor = F * G * VoH / (max(NoH, 0.001) * max(NoV, 0.001));
    
    return L;
}

float3 SampleDiffuseMicrofacetBRDF(in float3 V, in float3 N, in float3 baseColor, in float metallicness,
              in float fresnelReflect, in float roughness, in float3 random, out float3 nextFactor)
{
    // important sampling diffuse
      // pdf = cos(theta) * sin(theta) / PI
    float theta = asin(sqrt(random.y));
    float phi = 2.0 * PI * random.x;
    
      // sampled indirect diffuse direction in normal space
    float3 localDiffuseDir = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
    float3 L = mul(getNormalSpace(N), localDiffuseDir);
      
       // half vector
    float3 H = normalize(V + L);
    float VoH = clamp(dot(V, H), 0.0, 1.0);
    float NoV = clamp(dot(N, V), 0.0, 1.0);
    float NoL = clamp(dot(N, L), 0.0, 1.0);
      
      // F0 for dielectics in range [0.0, 0.16] 
      // default FO is (0.16 * 0.5^2) = 0.04
    float3 f0 = 0.16 * (fresnelReflect * fresnelReflect);
      // in case of metals, baseColor contains F0
    f0 = lerp(f0, baseColor, metallicness);
    float3 F = fresnelSchlick(VoH, f0);
      
    //float3 notSpec = float3(1.0, 1.0, 1.0) - F; // if not specular, use as diffuse
    //notSpec *= (1.0 - metallicness); // no diffuse for metals
    
    float disney = disneyDiffuseFactor(NoV, NoL, VoH, roughness);
    
    nextFactor = disney * (1.0 - metallicness) * baseColor;// / (PI * 0.5);
    
    //nextFactor = (1.0 - metallicness) * baseColor;
    
    //nextFactor = baseColor * PI * cos(theta) * sin(theta);
    //nextFactor = baseColor * sin(theta);
    //nextFactor = baseColor;
    
    return L;
}

#endif