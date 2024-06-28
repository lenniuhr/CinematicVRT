# Master's Thesis: Cinematic Rendering of Volumetric Data in Unity

In this work, a volumetric pathtracing algorithm for data like medical CT scans is presented. It is capable of creating hyperrealistic images with a progressive rendering approach. The images are almost noise-free after a few seconds.

<img src="https://github.com/lenniuhr/CinematicVRT/blob/main/Assets/Textures/Images/manix-rendering.png" width=22% height=22%> <img src="https://github.com/lenniuhr/CinematicVRT/blob/main/Assets/Textures/Images/mecanix-rendering.png" width=22% height=22%> <img src="https://github.com/lenniuhr/CinematicVRT/blob/main/Assets/Textures/Images/mummy.png" width=50% height=50%>

## Class Overview

The most important classes are found in the *"Assets/Scripts"* folder. Most of the scripts mainly contain relevant information  for the rendering process and provide it to the shaders. In the *"Assets/Editor/Import"* folder, scripts for importing volumetric data in different formats can be found.

**VolumeDataset.cs**: A ScriptableObject, representing the volumetric data. Contains the data as a 3D Texture and information about the volume such as the density range or the spacing.

**VolumeBoundingBox.cs**: Responsible for providing the volumetric data and related information to the shaders. 

**OctreeGenerator.cs**: Creates the hierarchical Octree data structure from the volume's 3D texture with compute shaders. This is used in the cinematic rendering algorithm.

**TransferFunction.cs**: A ScriptableObject, representing the transfer function, which maps density values from the volume onto PBR material properties.

**TransferFunctionManager.cs**: Responsible for providing the transfer function to the shaders. 

**EnvironmentManager.cs**: Provides an HDR environment map to the shaders.

**RenderModeRendererFeature.cs**: A ScriptableRendererFeature, which runs the cinematic rendering algorithm. It is responsible for the aggregation of multiple frames (progressive rendering). Can also run different render passes, e.g. an octree visualization.

**ToneMappingRendererFeature.cs**: Applies a color correction to the final image.

# Shader Overview

The shader files are found in the *"Assets/Shaders"* folder. A lot of code is outsourced to specific files in the *"Assets/Shaders/Library"* folder, and is used in the rendering passes. These files contain most interesting program logic:

**CinematicRendering**: The cinematic rendering pass.

**GenerateOctree.compute**: Contains the compute shader for the Octree generation, which is done by the OctreeGenerator class.

**Octree.hlsl**: Contains logic for the use of the Octree data structure.

**Volume.hlsl**: Contains functions for sampling density and gradient inside the volumetric data.

**RayUtils.hlsl**: Contains functions for generating rays and calculating intersections with the volume bounding box.

**PBR.hlsl**: Contains functions for evaluating the Microfacet BRDF at surface scattering events.

**PhaseFunction.hlsl**: Contains functions for evaluating the Henyey-Greenstein phase function at volumetric scattering events.







