#ifndef VOLUME_RENDERING_INCLUDED
#define VOLUME_RENDERING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/Shaders/DefaultInput.hlsl"
#include "Assets/Shaders/Octree.hlsl"
#include "Assets/Shaders/Library/Common.hlsl"

#define BOX_MIN float3(-0.5, -0.5, -0.5)
#define BOX_MAX float3(0.5, 0.5, 0.5)

float3 _ViewParams;
float4x4 _CamLocalToWorldMatrix;

float4x4 _VolumeWorldToLocalMatrix;
float4x4 _VolumeLocalToWorldMatrix;


float _Roughness;
float _Metallicness;


TEXTURE2D(_TransferTex);  SAMPLER(sampler_TransferTex);

TEXTURE3D(_VolumeTex);  SAMPLER(sampler_VolumeTex);

TEXTURE3D(_GradientTex);  SAMPLER(sampler_GradientTex);

TEXTURECUBE(_Skybox);       SAMPLER(sampler_Skybox);

float3 _VolumePosition;
float3 _VolumeScale;

float _MinDensity;
float _MaxDensity;

float _StepSize;
float _NormalOffset;
float _Threshold;

struct Ray
{
    float3 origin;
    float3 dir;
    float3 directionWS;
};

struct HitInfo
{
    bool didHit;
    float3 hitPoint;
};

HitInfo RayBoundingBox(Ray ray, float3 boxMin, float3 boxMax)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float3 invDir = 1 / ray.dir;
    float3 tMin = (boxMin - ray.origin) * invDir;
    float3 tMax = (boxMax - ray.origin) * invDir;
    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    
    if (tNear >= 0)
    {
        hitInfo.didHit = tNear <= tFar;
        hitInfo.hitPoint = ray.origin + ray.dir * tNear;
    }
    
    return hitInfo;
};

float3 GetVolumeCoordsOS(float3 positionOS)
{
    return InverseLerp(BOX_MIN, BOX_MAX, positionOS);
}

float3 GetVolumeCoords(float3 positionWS)
{
    float3 boxMin = _VolumePosition - _VolumeScale / 2.0;
    float3 boxMax = _VolumePosition + _VolumeScale / 2.0;
    return InverseLerp(boxMin, boxMax, positionWS);
}

bool InVolumeBoundsOS(float3 positionOS)
{
    return positionOS.x > BOX_MIN.x && positionOS.y > BOX_MIN.y && positionOS.z > BOX_MIN.z 
    && positionOS.x < BOX_MAX.x && positionOS.y < BOX_MAX.y && positionOS.z < BOX_MAX.z;
}

bool InVolumeBounds(float3 positionWS)
{
    float3 boxMin = _VolumePosition - _VolumeScale / 2.0;
    float3 boxMax = _VolumePosition + _VolumeScale / 2.0;
    return positionWS.x > boxMin.x && positionWS.y > boxMin.y && positionWS.z > boxMin.z 
    && positionWS.x < boxMax.x && positionWS.y < boxMax.y && positionWS.z < boxMax.z;
}

float SampleDensity(float3 uv)
{
    if (uv.x < 0.0 || uv.y < 0.0 || uv.z < 0.0 || uv.x > 1.0 || uv.y > 1.0 || uv.z > 1.0)
    {
        return 0;
    }
    return SAMPLE_TEXTURE3D_LOD(_VolumeTex, sampler_VolumeTex, uv, 0).r;
}

float3 ComputeNormal(float3 uv)
{
    float offsetXY = 1 * _NormalOffset / 256.0;
    float offsetZ = 1 * _NormalOffset / 256.0;
    
    float3 rightUV = uv + float3(offsetXY, 0, 0);
    float3 leftUV = uv + float3(-offsetXY, 0, 0);
    float3 topUV = uv + float3(0, offsetXY, 0);
    float3 bottomUV = uv + float3(0, -offsetXY, 0);
    float3 frontUV = uv + float3(0, 0, offsetZ);
    float3 backUV = uv + float3(0, 0, -offsetZ);
    
    float value = SampleDensity(uv);
    
    float rightValue = SampleDensity(rightUV);
    float leftValue = SampleDensity(leftUV);
    float topValue = SampleDensity(topUV);
    float bottomValue = SampleDensity(bottomUV);
    float frontValue = SampleDensity(frontUV);
    float backValue = SampleDensity(backUV);    

    float gx = leftValue - rightValue;
    float gy = bottomValue - topValue;
    float gz = backValue - frontValue;

    return float3(gx, gy, gz);
}

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

    // We save some light invariant BRDF terms so we don't have to recompute
    // them in the light loop. Take a look at DirectBRDF function for detailed explaination.
    half normalizationTerm;     // roughness * 4.0 + 2.0
    half roughness2MinusOne;    // roughness^2 - 1.0
};

void InitializeBRDFData(half3 albedo, half smoothness, half metallic, out MyBRDFData outBRDFData)
{
    half oneMinusDielectricSpec = kDielectricSpec.a;
    oneMinusDielectricSpec =  oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;

    half oneMinusReflectivity = oneMinusDielectricSpec;
    half reflectivity = half(1.0) - oneMinusReflectivity;
    half3 brdfDiffuse = albedo * oneMinusReflectivity;
    half3 brdfSpecular = lerp(kDieletricSpec.rgb, albedo, metallic);

    outBRDFData = (MyBRDFData)0;
    outBRDFData.albedo = albedo;
    outBRDFData.diffuse = brdfDiffuse;
    outBRDFData.specular = brdfSpecular;
    outBRDFData.reflectivity = reflectivity;

    outBRDFData.perceptualRoughness = (1.0 - smoothness);
    outBRDFData.roughness           = max(outBRDFData.perceptualRoughness * outBRDFData.perceptualRoughness, HALF_MIN_SQRT);
    outBRDFData.roughness2          = max(outBRDFData.roughness * outBRDFData.roughness, HALF_MIN);
    outBRDFData.grazingTerm         = saturate(smoothness + reflectivity);
    outBRDFData.normalizationTerm   = outBRDFData.roughness * half(4.0) + half(2.0);
    outBRDFData.roughness2MinusOne  = outBRDFData.roughness2 - half(1.0);

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

float3 phongBRDF(float3 lightDir, float3 viewDir, float3 normal, float3 phongDiffuseCol, float3 phongSpecularCol, float phongShininess) 
{
  float3 color = phongDiffuseCol;
  float3 reflectDir = reflect(-lightDir, normal);
  float specDot = max(dot(reflectDir, viewDir), 0.0);
  color += pow(specDot, phongShininess) * phongSpecularCol;
  return color;
}

#define SMALL_OFFSET 0.0001

float3 RayOctreeBB(float3 uv, float level, float3 position, float3 dir)
{
    float dim = OCTREE_DIM[level];
    
    float3 cellMin = BOX_MIN + (floor(uv * dim) / dim);
    float3 cellMax = BOX_MIN + (ceil(uv * dim) / dim); // TODO case when uv * octreedim is exactly integer
    
    float3 invDir = 1 / dir;
    float3 tMin = (cellMin - position) * invDir;
    float3 tMax = (cellMax - position) * invDir;
    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    
    float3 hitPoint = position + dir * (tFar + SMALL_OFFSET); // Push the position inside the box
        
    return hitPoint;
}

int LevelUpTree(int level, float3 uv)
{
    int newLevel = level;
    while (newLevel < _OctreeLevel)
    {
        newLevel++;
        float value = GetOctreeValue(newLevel, uv);
        
        if (value <= _Threshold)
        {
            break;
        }
    }
    return newLevel;
}

uint NextRandom(inout uint state)
{
    state = state * 747796405 + 2891336453;
    uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
    result = (result >> 22) ^ result;
    return result;
}

float RandomValue(inout uint state)
{
    return NextRandom(state) / 4294967295.0; // 2^32 - 1
}

float4 RayMarchOctree(float3 position, Ray ray)
{
    //float3 step = ray.dir * _StepSize;
    float4 output = 0;

    int steps = 0;
    
    float level = 0;
    
    float octreeDim = OCTREE_DIM[level];
    
    // Octree id
    int3 parentId;
    
    [loop]
    for (int i = 0; i < 720; i++)
    {
        //position += step;
        
        if (!InVolumeBoundsOS(position))
        {
            break;
        }
        
        float3 uv = GetVolumeCoordsOS(position);
        float value = GetOctreeValue(level, uv);
        
        // Remove
        int dim = OCTREE_DIM[level];
    
        int x = clamp(floor(uv.x * dim), 0, dim - 1);
        int y = clamp(floor(uv.y * dim), 0, dim - 1);
        int z = clamp(floor(uv.z * dim), 0, dim - 1);

        int index = dim * dim * z + dim * y + x;
        
        /*if (index > 0)
        {
            return float4(uv, 1);
            return value;
        }
        else
        {
            // Calculate step
            float3 hitPoint = RayOctreeBB(uv, octreeDim, position, ray.dir);
            float3 newUV = GetVolumeCoordsOS(hitPoint);
            return float4(newUV, 1);

        }*/
        
        if (value > _Threshold)
        {
            level = LevelUpTree(level, uv);
            parentId = GetOctreeId(level - 1, uv);
            
            value = GetOctreeValue(level, uv);
                
            if (value > _Threshold)
            {
                output = value;
                
                output = RandomValue(index);
                break;
            }
        }
        else
        {
            if (level > 0)
            {
                int3 currentId = GetOctreeId(level - 1, uv);
                if (currentId.x != parentId.x || currentId.y != parentId.y || currentId.z != parentId.z)
                {
                    float parentValue = GetOctreeValue(level - 1, uv);
                    if (parentValue <= _Threshold)
                    {
                            level--;
                    }
                }
            }
        }
                
        // Calculate step
        float3 hitPoint = RayOctreeBB(uv, level, position, ray.dir);
        position = hitPoint;
        
        steps++;
    }
    //return 0.4 * step(4, steps);
    
    return pow((float) steps / 80.0, 1);
    return output;
}

float4 RayMarch(float3 position, Ray ray)
{
    float3 step = ray.dir * _StepSize;
    float4 output = 0;

    int steps = 0;
    
    [loop]
    for (int i = 0; i < 720; i++)
    {
        position += step;
        steps++;
        
        if (!InVolumeBoundsOS(position))
        {
            break;
        }
        
        float3 uv = GetVolumeCoordsOS(position);
        
        float density = SampleDensity(uv);
        
        if (density > _Threshold)
        {
            //return density;
        }

        half3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;

        float2 transferUV = float2(density, length(gradient));
        half4 color = SAMPLE_TEXTURE2D_LOD(_TransferTex, sampler_TransferTex, transferUV, 0);
        
        if(color.a < 0.001)
        {
            continue;
        }
        

        float3 normalWS = mul((float3x3)_VolumeLocalToWorldMatrix, gradient);
        normalWS = normalize(normalWS);

        //normal = mul((float3x3)_VolumeLocalToWorldMatrix, ComputeNormal(uv));

        float shininess = 0.0;
        float irradiPerp = 1;
        float4 specularColor = float4(0,0,0,0);

        float3 mainLightPositionOS = mul(_VolumeWorldToLocalMatrix, _MainLightPosition).xyz;
        
        float3 lightDir = normalize(mainLightPositionOS - position);
        float irradiance = max(dot(lightDir, normalWS), 0.0) * irradiPerp;

        float3 brdf = 0;

        if(irradiance > 0.0) 
        {
            brdf = phongBRDF(lightDir, -ray.directionWS, normalWS, color.rgb, specularColor.rgb, shininess);

        }

        // Old

        half3 gi = SampleSH(normalWS);
        //color.rgb *= gi;

        // PBR

        color.rgb = PBRLighting(color.rgb, 1 - _Roughness , _Metallicness, -ray.directionWS, normalWS, gi);


        // alpha is per 0.1 units
        float transparency = _StepSize / 0.002;

        float oneMinusAlpha = 1.0 - output.a;
        output.a += oneMinusAlpha * color.a * transparency;
        output.rgb += oneMinusAlpha * color.a * transparency * color.rgb;

        if(output.a > 0.999)
        {
            break;
        }
    }

    //return pow((float) steps / 600.0, 1);
    
    return output;//pow(output, 2.2);
}

HitInfo RayBoundingBoxOS(Ray ray)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    // Return hit when ray origin is in bounds
    if (InVolumeBoundsOS(ray.origin))
    {
        hitInfo.didHit = true;
        hitInfo.hitPoint = ray.origin;
        return hitInfo;
    }
    
    float3 invDir = 1 / ray.dir;
    float3 tMin = (BOX_MIN - ray.origin) * invDir;
    float3 tMax = (BOX_MAX - ray.origin) * invDir;
    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    
    if (tNear >= 0)
    {
        hitInfo.didHit = tNear <= tFar;
        hitInfo.hitPoint = ray.origin + ray.dir * (tNear + SMALL_OFFSET); // Push the position inside the box
    }
    
    return hitInfo;
};

float4 OctreeFragment(Varyings IN) : SV_TARGET
{
    float3 viewPointLocal = float3(IN.uv - 0.5, 1) * _ViewParams;
    float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1)).xyz;
    
    float3 originWS = _WorldSpaceCameraPos;
    float3 dirWS = normalize(viewPoint - originWS);
    
    Ray ray;
    ray.origin = mul(_VolumeWorldToLocalMatrix, float4(originWS, 1)).xyz;
    ray.dir = mul((float3x3) _VolumeWorldToLocalMatrix, dirWS);
    ray.directionWS = dirWS;
    
    HitInfo hit = RayBoundingBoxOS(ray);
    if (hit.didHit)
    {
        half4 output = RayMarchOctree(hit.hitPoint, ray);
        return output;
    }
    return half4(0, 0, 0, 1);
}

float4 RaytraceFragment(Varyings IN) : SV_TARGET
{
    
    return half4(0.5, 0.001, 0.001, 1);
}

float4 VolumeRenderingFragment(Varyings IN) : SV_TARGET
{
    float3 viewPointLocal = float3(IN.uv - 0.5, 1) * _ViewParams;
    float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1)).xyz;
    
    float3 originWS = _WorldSpaceCameraPos;
    float3 dirWS = normalize(viewPoint - originWS);
    
    //return SAMPLE_TEXTURE2D(_TransferTex, sampler_TransferTex, IN.uv);
    
    Ray ray;
    ray.origin = mul(_VolumeWorldToLocalMatrix, float4(originWS, 1)).xyz;
    ray.dir = mul((float3x3) _VolumeWorldToLocalMatrix, dirWS);
    ray.directionWS = dirWS;

    half4 skyData = SAMPLE_TEXTURECUBE(_Skybox, sampler_Skybox, dirWS);
    
    HitInfo hit = RayBoundingBoxOS(ray);

    //half3 gi = SampleSH(dirWS);
    //return half4(gi, 1);
    
    if (hit.didHit)
    {
        half4 output = RayMarch(hit.hitPoint, ray);
        output += (1.0 - output.a) * saturate(skyData);
        return output;
    }

    //half mip = PerceptualRoughnessToMipmapLevel(info.perceptualRoughness);
    //half4 encodedIrradiance = half4(SAMPLE_TEXTURECUBE_LOD(_GlossyEnvironmentCubeMap, sampler_GlossyEnvironmentCubeMap, reflectVector, mip));
    //half3 indirectSpecular = DecodeHDREnvironment(encodedIrradiance, _GlossyEnvironmentCubeMap_HDR);
    
    //return float4(0, 0, 0, 1);
    return skyData;
}

#endif