#ifndef RAYTRACING_MATERIAL_INCLUDED
#define RAYTRACING_MATERIAL_INCLUDED

struct RayTracingMaterial
{
    float3 color;
    float roughness;
    float metallic;
    float alpha;
    float reflectance;
};

#endif