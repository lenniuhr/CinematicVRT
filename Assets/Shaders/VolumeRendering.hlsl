#ifndef VOLUME_RENDERING_INCLUDED
#define VOLUME_RENDERING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/Shaders/DefaultInput.hlsl"

#define BOX_MIN float3(-0.5, -0.5, -0.5)
#define BOX_MAX float3(0.5, 0.5, 0.5)

float3 _ViewParams;
float4x4 _CamLocalToWorldMatrix;

float4x4 _VolumeWorldToLocalMatrix;


TEXTURE2D(_TransferTex);  SAMPLER(sampler_TransferTex);

TEXTURE3D(_VolumeTex);  SAMPLER(sampler_VolumeTex);

TEXTURE3D(_GradientTex);  SAMPLER(sampler_GradientTex);

float3 _VolumePosition;
float3 _VolumeScale;

float _StepSize;
float _NormalOffset;
float _Threshold;

struct Ray
{
    float3 origin;
    float3 dir;
};

struct HitInfo
{
    bool didHit;
    float3 hitPoint;
};

float InverseLerp(float from, float to, float value)
{
    return saturate((value - from) / (to - from));
}

float3 InverseLerp(float3 from, float3 to, float3 value)
{
    return saturate((value - from) / (to - from));
}

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
    return SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, uv).r;
}

float GetBlurredDensity(float3 uv)
{
    float offsetXY = 1 / 512.0;
    
    float3 rightUV = uv + float3(offsetXY, 0, 0);
    float3 leftUV = uv + float3(-offsetXY, 0, 0);
    float3 topUV = uv + float3(0, offsetXY, 0);
    float3 bottomUV = uv + float3(0, -offsetXY, 0);
    
    float3 rightTopUV = uv + float3(offsetXY, offsetXY, 0);
    float3 leftTopUV = uv + float3(-offsetXY, offsetXY, 0);
    float3 rightBottomUV = uv + float3(offsetXY, -offsetXY, 0);
    float3 leftBottomUV = uv + float3(-offsetXY, -offsetXY, 0);
    
    float value = SampleDensity(uv);
    
    float rightValue = SampleDensity(rightUV);
    float leftValue = SampleDensity(leftUV);
    float topValue = SampleDensity(topUV);
    float bottomValue = SampleDensity(bottomUV);
    
    float rightTopValue = SampleDensity(rightTopUV);
    float leftTopValue = SampleDensity(leftTopUV);
    float rightBottomValue = SampleDensity(rightBottomUV);
    float leftBottomValue = SampleDensity(leftBottomUV);
    
    float gaussian = (1 / 16.0) * (4 * value + 2 * rightValue + 2 * leftValue + 2 * topValue + 2 * bottomValue
    + rightTopValue + leftTopValue + rightBottomValue + leftBottomValue);

    return gaussian;
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
    
    /*float value = GetBlurredDensity(uv);
    
    float rightValue = GetBlurredDensity(rightUV);
    float leftValue = GetBlurredDensity(leftUV);
    float topValue = GetBlurredDensity(topUV);
    float bottomValue = GetBlurredDensity(bottomUV);
    float frontValue = GetBlurredDensity(frontUV);
    float backValue = GetBlurredDensity(backUV);*/
    

    float gx = leftValue - rightValue;
    float gy = bottomValue - topValue;
    float gz = backValue - frontValue;

    return float3(gx, gy, gz);
}

float4 RayMarchVolume(float3 position, float3 direction)
{
    float3 step = direction * _StepSize;
    
    [loop]
    for (int i = 0; i < 720; i++)
    {
        position += step;
        
        if (!InVolumeBounds(position))
        {
            return 0;
        }
        
        float3 uv = GetVolumeCoords(position);
        
        float density = SampleDensity(uv);
        
        if (density > _Threshold)
        {
            float3 normal = ComputeNormal(uv);
            return float4(normal, 1);
            
            //density = GetBlurredDensity(uv);
            
            return density;
        }
    }

    return 0;
}

float3 phongBRDF(float3 lightDir, float3 viewDir, float3 normal, float3 phongDiffuseCol, float3 phongSpecularCol, float phongShininess) 
{
  float3 color = phongDiffuseCol;
  float3 reflectDir = reflect(-lightDir, normal);
  float specDot = max(dot(reflectDir, viewDir), 0.0);
  color += pow(specDot, phongShininess) * phongSpecularCol;
  return color;
}

float4 RayMarch(float3 position, float3 direction)
{
    float3 step = direction * _StepSize;
    float4 output = 0;
    
    [loop]
    for (int i = 0; i < 720; i++)
    {
        position += step;
        
        if (!InVolumeBoundsOS(position))
        {
            break;
            return output;
        }
        
        float3 uv = GetVolumeCoordsOS(position);
        
        float density = SampleDensity(uv);
        
        if (density > _Threshold)
        {
            //return density;
        }

        half3 normal = SAMPLE_TEXTURE3D(_GradientTex, sampler_GradientTex, uv).xyz;
            
        float2 transferUV = float2(density, length(normal));
        half4 color = SAMPLE_TEXTURE2D(_TransferTex, sampler_TransferTex, transferUV);

        // Blinn-Phong

        float shininess = 0.0;
        float irradiPerp = 1;
        float4 specularColor = float4(0,0,0,0);

        float3 mainLightPositionOS = mul(_VolumeWorldToLocalMatrix, _MainLightPosition).xyz;
        
        float3 lightDir = normalize(mainLightPositionOS - position);
        float irradiance = max(dot(lightDir, normal), 0.0) * irradiPerp;

        if(irradiance > 0.0) 
        {
            float3 brdf = phongBRDF(lightDir, direction, normal, color.rgb, specularColor.rgb, shininess);
            color.rgb = brdf * irradiance * _MainLightColor.rgb;

            output += (1.0 - output.a) * color;
        }


            //return color;
            
            //return float4(normal, 1) * 3;
            
            //float4 color = SAMPLE_TEXTURE2D(_TransferTex, sampler_TransferTex, float2(density, 0.5));
            //color.rgb *= color.a * 0.5;
            //output += (1.0 - output.a) * color;
        //}
    }
    
    return output;
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
        hitInfo.hitPoint = ray.origin + ray.dir * tNear;
    }
    
    return hitInfo;
};

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
    
    HitInfo hit = RayBoundingBoxOS(ray);
    
    if (hit.didHit)
    {
        return RayMarch(hit.hitPoint, ray.dir);
    }
    return float4(0.1, 0.1, 0.1, 1);
}

#endif