using UnityEngine;
using static VolumeClassifier;

public static class ShaderHelper
{
    public static void Dispatch(ComputeShader computeShader, int kernelIndex, int dimX, int dimY, int dimZ)
    {
        computeShader.GetKernelThreadGroupSizes(kernelIndex, out uint threadGroupSizeX, out uint threadGroupSizeY, out uint threadGroupSizeZ);
        int threadGroupsX = Mathf.CeilToInt(dimX / (float)threadGroupSizeX);
        int threadGroupsY = Mathf.CeilToInt(dimY / (float)threadGroupSizeY);
        int threadGroupsZ = Mathf.CeilToInt(dimZ / (float)threadGroupSizeZ);

        computeShader.Dispatch(kernelIndex, threadGroupsX, threadGroupsY, threadGroupsZ);
    }
    
    public static void CreateStructuredBuffer<T>(ref ComputeBuffer buffer, int count, ComputeBufferMode usage = ComputeBufferMode.Immutable)
    {
        count = Mathf.Max(1, count); // cannot create 0 length buffer
        int stride = GetStride<T>();
        bool createNewBuffer = buffer == null || !buffer.IsValid() || buffer.count != count || buffer.stride != stride;
        if (createNewBuffer)
        {
            buffer?.Release();
            buffer = new ComputeBuffer(count, stride, ComputeBufferType.Structured, usage);
        }
    }

    public static int GetStride<T>() => System.Runtime.InteropServices.Marshal.SizeOf(typeof(T));

    public static void CreateRenderTexture3D(ref RenderTexture texture, int width, int height, int depth, string name)
    {
        if (texture == null || !texture.IsCreated() || texture.width != width || texture.height != height || texture.volumeDepth != depth)
        {
            Debug.Log ("Create 3D RenderTexture: " + name);
            if (texture != null)
            {
                texture.Release();
            }
            const int numBitsInDepthBuffer = 0;
            texture = new RenderTexture(width, height, numBitsInDepthBuffer, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            texture.volumeDepth = depth;
            texture.enableRandomWrite = true;
            texture.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
            texture.useMipMap = false;
            texture.autoGenerateMips = false;
            texture.Create();
        }
        texture.wrapMode = TextureWrapMode.Clamp;
        texture.filterMode = FilterMode.Bilinear;
        texture.name = name;
    }
    public static RenderTexture CreateRenderTexture3D(int width, int height, int depth, string name)
    {
        Debug.Log("Create 3D RenderTexture: " + name);
            
        const int numBitsInDepthBuffer = 0;
        RenderTexture texture = new RenderTexture(width, height, numBitsInDepthBuffer, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        texture.volumeDepth = depth;
        texture.enableRandomWrite = true;
        texture.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        texture.useMipMap = false;
        texture.autoGenerateMips = false;
        texture.Create();
        
        texture.wrapMode = TextureWrapMode.Clamp;
        texture.filterMode = FilterMode.Bilinear;
        texture.name = name;

        return texture;
    }
}
