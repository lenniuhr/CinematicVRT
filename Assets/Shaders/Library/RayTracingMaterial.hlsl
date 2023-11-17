#ifndef RAYTRACING_MATERIAL_INCLUDED
#define RAYTRACING_MATERIAL_INCLUDED

struct RayTracingMaterial
{
    float3 color;
    float metallicness;
    float roughness;
    float reflectance;
};

#endif