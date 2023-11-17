#ifndef CINEMATIC_RENDERING_INCLUDED
#define CINEMATIC_RENDERING_INCLUDED

#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Random.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/Octree.hlsl"
#include "Assets/Shaders/Library/Classification.hlsl"
#include "Assets/Shaders/Library/Environment.hlsl"

TEXTURE2D(_CopyTex);    SAMPLER(sampler_point_clamp);
TEXTURE2D(_ResultTex);    
TEXTURE2D(_PrevFrame);
TEXTURE2D(_CurrentFrame);

TEXTURE2D(_TransferTex);  SAMPLER(sampler_TransferTex);

TEXTURECUBE(_Skybox);       SAMPLER(sampler_Skybox);


float4 _Color;

int _FrameID;
float _Threshold;

HitInfo RaymarchCell(int level, int3 currentId, float3 position, float3 dirOS)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float3 stopPos = position;
    RayOctree(dirOS, level, currentId, stopPos);
    
    // TODO: do i need to check at position and newPos ?
    float3 t = stopPos - position;
    float3 step = t / 20;
    for (int i = 0; i <= 20; i++)
    {
        float3 stepPos = position + i * step;
        
        float3 uv = GetVolumeCoords(stepPos);
        
        float4 classification = SampleClassification(uv);
        float maxValue = max(max(max(classification.r, classification.g), classification.b), classification.a);
                    
        if (maxValue > _Threshold) // Surface hit
        {
            hitInfo.didHit = true;
            hitInfo.hitPointOS = stepPos - step;
            uv = GetVolumeCoords(hitInfo.hitPointOS);
            hitInfo.normalOS = SampleNormal(uv);
            
            //hitInfo.material.color = GetClassColor(classification);
            //hitInfo.material.color = (float) i / 10.0;
            hitInfo.material = GetMaterial(classification);
            
            return hitInfo;
        }
    }
    hitInfo.didHit = false;
    return hitInfo;
}

HitInfo TraverseOctree(float3 position, Ray ray)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    int octreeLevel = 0;
    float3 uv = GetVolumeCoords(position);
    int3 octreeId = GetOctreeId(octreeLevel, uv);
    
    if (!IsValid(position, ray.dirOS, octreeLevel, octreeId))
    {
        return hitInfo;
    }
    
    [loop]
    for (int i = 0; i < 256; i++)
    {
        float value = GetOctreeValueById(octreeLevel, octreeId);
        
    // when the current cell is above the threshold, increase the octree level
        if (value > _Threshold)
        {
            uv = GetVolumeCoords(position);
            
            IncreaseOctreeLevel(octreeLevel, octreeId, uv, _Threshold);
            
        // When the threshold is reached on max level, break
            value = GetOctreeValueById(octreeLevel, octreeId);
            if (octreeLevel >= 7 && value > _Threshold)
            {
                hitInfo = RaymarchCell(octreeLevel, octreeId, position, ray.dirOS);
                
                if (hitInfo.didHit)
                {
                    return hitInfo;
                }
            }
        }
        else
        {
        // Check if the octree level can be lowered again
            if (octreeLevel > 0)
            {
                ReduceOctreeLevel(octreeLevel, octreeId, _Threshold);
            }
        }
        
        bool valid = RayOctree(ray.dirOS, octreeLevel, octreeId, position);
        
        if (!valid)
        {
            break;
        }
        
    // Break when the octree id is out of bounds
        if (IsInvalid(octreeLevel, octreeId))
        {
            break;
        }
    }
    return hitInfo;
}

int IncreaseOctreeLevel(int level, float3 uv)
{
    int newLevel = level;
    while (newLevel < OCTREE_DEPTH)
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

float Halton(uint base, uint index)
{
    float result = 0;
    float digitWeight = 1;
    while (index > 0u)
    {
        digitWeight = digitWeight / float(base);
        uint nominator = index % base;
        result += float(nominator) * digitWeight;
        index = index / base;
    }
    return result;
}


HitInfo RayMarchVolumeCollision(float3 position, Ray ray, inout uint rngState)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float _StepSize = 0.001;
    
    position += ray.dirOS * 0.001;
    
    [loop]
    for (int i = 0; i < 1000; i++)
    {
        if (!InVolumeBoundsOS(position))
        {
            // TODO ray goes out of volume
            return hitInfo;
        }
           
        float3 uv = GetVolumeCoords(position);
        float density = SampleDensity(uv);
        
        float4 classification = SampleClassification(uv);
        
        if (length(classification) > _Threshold)
        {
            if (RandomValue(rngState) > 0.8)
            {
                float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
                
                float3 normalOS = normalize(gradient);
                
                hitInfo.didHit = true;
                hitInfo.hitPointOS = position - ray.dirOS * _StepSize;
                hitInfo.normalOS = normalOS;
                hitInfo.material.color = GetClassColor(classification);;
                
                return hitInfo;
            }
        }
        position += normalize(ray.dirOS) * _StepSize;
    }
    return hitInfo;
}

HitInfo CalculateRayVolumeCollision(float3 position, Ray ray)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    int octreeLevel = 0;
    float octreeDim = OCTREE_DIM[octreeLevel];
    
    // Octree id
    int3 parentId;
    
    [loop]
    for (int i = 0; i < 300; i++)
    {
        if (!InVolumeBoundsOS(position))
        {
            // TODO ray goes out of volume
            return hitInfo;
        }
        
        float3 uv = GetVolumeCoords(position);
        float value = GetOctreeValue(octreeLevel, uv);
        
        if (value > _Threshold)
        {
            octreeLevel = IncreaseOctreeLevel(octreeLevel, uv);
            parentId = GetOctreeId(octreeLevel - 1, uv);
            
            value = GetOctreeValue(octreeLevel, uv);
                
            if (value > _Threshold)
            {
                for (int step = 0; step < 50; step++)
                {
                    float density = SampleDensity(uv);
                    if (density > _Threshold)
                    {
                        // Surface hit
                        float density = SampleDensity(uv);
                        float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
                
                        float2 transferUV = float2(density, length(gradient));
                        float4 color = SAMPLE_TEXTURE2D_LOD(_TransferTex, sampler_TransferTex, transferUV, 0);
                        
                
                        float3 normalWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, gradient));
                        float3 normalOS = normalize(gradient);
                
                        hitInfo.didHit = true;
                        hitInfo.hitPointOS = position + 0.01 * normalOS;
                        hitInfo.normalOS = normalOS;
                        hitInfo.material.color = _Color;
                
                        return hitInfo;
                    }
                    else
                    {
                        position += ray.dirOS * (1 / 512.0) * 0.5;
                    }
                }
            }
        }
        else
        {
            if (octreeLevel > 0)
            {
                int3 currentId = GetOctreeId(octreeLevel - 1, uv);
                if (currentId.x != parentId.x || currentId.y != parentId.y || currentId.z != parentId.z)
                {
                    float parentValue = GetOctreeValue(octreeLevel - 1, uv);
                    if (parentValue <= _Threshold)
                    {
                        octreeLevel--;
                    }
                }
            }
        }
                
        // Calculate step
        float3 hitPoint = RayOctreeBB(uv, octreeLevel, position, ray.dirOS);
        position = hitPoint;
    }
    return hitInfo;
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
    float denom = NdotV * (1.0 - k) + k;
    return NdotV / denom;
}

float G_Smith(float NoV, float NoL, float roughness)
{
    float g1_l = G1_GGX_Schlick(NoL, roughness);
    float g1_v = G1_GGX_Schlick(NoV, roughness);
    return g1_l * g1_v;
}

float3 GetSpecularDir(in float3 V, in float3 N, in float3 baseColor, in float metallicness,
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
      
    float3 notSpec = float3(1.0, 1.0, 1.0) - F; // if not specular, use as diffuse
    notSpec *= (1.0 - metallicness); // no diffuse for metals
    
    float disney = disneyDiffuseFactor(NoV, NoL, VoH, roughness);
    
    nextFactor = disney * (1.0 - metallicness) * baseColor;
    
    //nextFactor = 1 - disney;
    
    return L;
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



float3 Trace(float3 position, Ray ray, inout uint rngState)
{
    float3 color = 1;
    float3 incomingLight = 0;
    
    for (int i = 0; i <= 3; i++)
    {
        HitInfo hit = TraverseOctree(position, ray);
        if (hit.didHit)
        {
            /*
            // Diffuse
            ray.originOS = hit.hitPointOS;
            ray.dirOS = normalize(normalize(hit.normalOS) + RandomDirection(rngState));
            position = hit.hitPointOS;
            color *= hit.material.color;
            */
            
            //float3 randomVec = normalize(float3(RandomValue(rngState), RandomValue(rngState), RandomValue(rngState)) * 2 - 1);
            
            /*
            // BRDF
            position = hit.hitPointOS;
            ray.originOS = hit.hitPointOS;
            float3 newDirOS = normalize(normalize(hit.normalOS) + RandomDirection(rngState));
            
            float3 brdf = MicrofacetBRDF(newDirOS, -ray.dirOS, hit.normalOS, hit.material.color, 0.0, 0.5, 0.2);
            float illuminance = max(dot(newDirOS, hit.normalOS), 0.0);
            color *= brdf;// * illuminance;
            
            ray.dirOS = newDirOS;
            */
            
            // Specular
                
            float3 r = float3(RandomValue(rngState), RandomValue(rngState), RandomValue(rngState));
            
            float3 nextFactor;
            float3 nextDir;
            if (RandomValue(rngState) > 0.5)
            {
                nextDir = GetSpecularDir(-ray.dirOS, hit.normalOS, hit.material.color, hit.material.metallicness, hit.material.reflectance, hit.material.roughness, r, nextFactor);
                ray.type = 2;
            }
            else
            {
                nextDir = SampleDiffuseMicrofacetBRDF(-ray.dirOS, hit.normalOS, hit.material.color, hit.material.metallicness, hit.material.reflectance, hit.material.roughness, r, nextFactor);
                ray.type = 1;
            }
            
            position = hit.hitPointOS;
            ray.originOS = hit.hitPointOS;
            ray.dirOS = nextDir;
            color *= nextFactor * 2;
            
            
            
            //return hit.normalOS;
            
            //position = hit.hitPointOS;
            //ray.originOS = hit.hitPointOS;
            //ray.dirOS = reflect(ray.dirOS, hit.normalOS);
            //color *= hit.material.color;

        }
        else
        {
            float3 dirWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, ray.dirOS));
            
            float4 skyData = SampleEnvironment(dirWS, ray.type);
            
            incomingLight = color * skyData.rgb;
            
            break;
        }
    }
    
    return incomingLight;
}


float3 TraceSSS(float3 position, Ray ray, inout uint rngState)
{
    float3 color = 1;
    float3 incomingLight = 0;
    
    for (int i = 0; i <= 2; i++)
    {
        HitInfo hit = RayMarchVolumeCollision(position, ray, rngState);
        //HitInfo hit = TraverseOctree(position, ray);
        if (hit.didHit)
        {
            ray.originOS = hit.hitPointOS;
            ray.dirOS = normalize(normalize(hit.normalOS) + RandomDirection(rngState));
            position = hit.hitPointOS;
            color *= hit.material.color;
        }
        else
        {
            float3 dirWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, ray.dirOS));
            float4 skyData = SampleEnvironment(dirWS, ray.type);
            incomingLight = color * skyData.rgb;
            break;
        }
    }
    return incomingLight;
}

float4 SampleEnvironmentMap(float3 dirWS)
{
    float s = frac(1.0 / (2.0 * PI) * atan2(-dirWS.x, -dirWS.z));
    float t = 1.0 / (PI) * acos(-dirWS.y);
    float2 uv = float2(s, t);
    
    return 0;
    //return SAMPLE_TEXTURE2D_LOD(_EnvironmentMap, sampler_EnvironmentMap, uv, 0);
}

float4 RaytraceFragment(Varyings IN) : SV_TARGET
{
    float2 pixelOffset = float2(Halton(2, _FrameID) - 0.5, Halton(3, _FrameID) - 0.5) / _ScreenParams.xy;
    
    //return Rand3dTo1d(float3(IN.uv, _FrameID));
    
    // Create seed for random number generator
    uint2 numPixels = _ScreenParams.xy;
    uint2 pixelCoord = IN.uv * numPixels;
    uint pixelIndex = pixelCoord.y * numPixels.x + pixelCoord.x;
    uint rngState = pixelIndex + _FrameID * 719393;
    
    Ray ray = GetRay(IN.uv, pixelOffset);
    
    float3 hitPoint;
    if (RayBoundingBoxOS(ray, hitPoint))
    {
        float3 color = TraceSSS(hitPoint, ray, rngState);
        return float4(color, 1);
    }
            
    float4 skyData = SampleEnvironment(ray.dirWS, 0);
    return skyData;
}

float4 CopyFragment(Varyings IN) : SV_TARGET
{
    return SAMPLE_TEXTURE2D(_CopyTex, sampler_point_clamp, IN.uv);
}

float4 AccumulateFragment(Varyings IN) : SV_Target
{
    float4 color = SAMPLE_TEXTURE2D(_CurrentFrame, sampler_point_clamp, IN.uv);
    float4 prevColor = SAMPLE_TEXTURE2D(_PrevFrame, sampler_point_clamp, IN.uv);
    
    float weight = 1.0 / (_FrameID + 1.0);
    
    float4 accumulatedColor = prevColor * (1.0 - weight) + color * weight;
				
    return accumulatedColor;
}

#endif