# Master's Thesis: Cinematic Rendering of Volumetric Data in Unity

In this work, a volumetric pathtracing algorithm for data like medical CT scans is presented. 

![alt text](https://github.com/lenniuhr/CinematicVRT/blob/[branch]/image.jpg?raw=true)

## Class Overview

The most important classes are found in the "Assets/Scripts" folder.

**VolumeDataset**: The representation of the volumetric data. Contains the data as 3D Texture and information about the volume such as the density range or the spacing.

**VolumeBoundingBox**: Responsible for providing the volumetric data and related information to the shaders. 

**OctreeGenerator**: Creates the hierarchical octree data structure from the volume's 3D texture with compute shaders. This is used in the cinematic rendering algorithm.

**TransferFunction**: The representation of the transfer function, which maps density values from the volume onto PBR material properties.

**TransferFunctionManager**: Responsible for providing the transfer function to the shaders. 

**EnvironmentManager**: Provides an HDR environment map to the shaders.

**RenderModeRendererFeature**: A ScriptableRendererFeature, which runs the cinematic rendering algorithm. It is responsible for the aggregation of multiple frames (progressive rendering). Can also run different render passes, e.g. an octree visualization.

# Shader Overview

The shader files are found in the "Assets/Shaders" folder. A lot of code is outsourced to specific files in the "Assets/Shaders/Library" folder.

These files contain most of the program logic:

**CinematicRendering**: The cinematic rendering pass.

**GenerateOctree.compute**: Contains the computer shader for the octree generation, which is done by the OctreeGenerator class.

**Octree.hlsl**: Contains logic for the use of the octree data structure.

**Volume.hlsl**: Contains functions for sampling density and gradient inside the volumetric data.

**RayUtils.hlsl**: Contains functions for generating rayss and calculating intersections with the olume bounding box.

**PBR.hlsl**: Contains functions for evaluating the microfacet brdf at surface scattering events.

**PhaseFunction.hlsl**: Contains functions for evaluating the Henyey-Greenstein phase function at volumetric scattering events.







