using System;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;


[ExecuteInEditMode]
public class TextureGenerator : MonoBehaviour
{
    public Texture2D texture;

    public Cubemap cubemap;

    public ComputeShader computeShader;

    public Texture3D texture3D;

    private Material material;

    public int Slice;


    public Texture displayImage;

    public BlurFilterMode filterMode;
    [Range(0, 100)]
    public int kernelRadius;
    [Range(0.001f, 100)]
    public float sigma;
    [Range(0.001f, 10)]
    public float sigmaR;

    public enum BlurFilterMode
    {
        Bilateral = 0,
        Gaussian = 1
    }

    private enum Pass
    {
        BilateralBlur,
        GaussianBlur,
        BilateralBlur3D,
        GaussianBlur3D
    }

    private void OnEnable()
    {
        material = CoreUtils.CreateEngineMaterial("Hidden/BlurImage");
        material.hideFlags = HideFlags.HideAndDontSave;

        UpdateShaderParams();
    }

    private void OnValidate()
    {
        if(material)
        {
            UpdateShaderParams();
        }
    }

    private void UpdateShaderParams()
    {
        material.SetTexture("_VolumeTex", texture3D);
        material.SetInt("_KernelRadius", kernelRadius);
        material.SetFloat("_Sigma", sigma);
        material.SetFloat("_SigmaR", sigmaR);
    }

    public void BlurCubemap()
    {
        Debug.Log($"Cubemap has width {cubemap.width}");
        Debug.Log($"Cubemap format: {cubemap.format}");

        Texture2D result = new Texture2D(cubemap.width, cubemap.width, TextureFormat.RGBAFloat, false);

        result.SetPixels(cubemap.GetPixels(CubemapFace.PositiveZ, 0), 0);
        result.Apply();

        displayImage = result;

       
        // Copy cubemap faces to Texture2DArray

        Texture2DArray cubemapFaces = new Texture2DArray(cubemap.width, cubemap.width, 6, TextureFormat.RGBAFloat, false);
        cubemapFaces.SetPixels(cubemap.GetPixels(CubemapFace.PositiveX, 0), 0);
        cubemapFaces.SetPixels(cubemap.GetPixels(CubemapFace.NegativeX, 0), 1);
        cubemapFaces.SetPixels(cubemap.GetPixels(CubemapFace.PositiveY, 0), 2);
        cubemapFaces.SetPixels(cubemap.GetPixels(CubemapFace.NegativeY, 0), 3);
        cubemapFaces.SetPixels(cubemap.GetPixels(CubemapFace.PositiveZ, 0), 4);
        cubemapFaces.SetPixels(cubemap.GetPixels(CubemapFace.NegativeZ, 0), 5);
        cubemapFaces.Apply();


        RenderTexture resultArray = new RenderTexture(cubemap.width, cubemap.width, 0, RenderTextureFormat.ARGBFloat);
        resultArray.volumeDepth = 6;
        resultArray.enableRandomWrite = true;
        resultArray.dimension = TextureDimension.Tex2DArray;
        resultArray.useMipMap = false;
        resultArray.autoGenerateMips = false;
        resultArray.wrapMode = TextureWrapMode.Clamp;
        resultArray.filterMode = FilterMode.Bilinear;
        resultArray.Create();

        // Copy Texture2DArray to RenderTexture

        //Graphics.CopyTexture(cubemapFaces, 0, resultArray, 0);

        // Run compute shader
        int classifyKernel = computeShader.FindKernel("GenerateCubemap");

        computeShader.SetTexture(classifyKernel, "_Cubemap", cubemap);

        computeShader.SetTexture(classifyKernel, "_Result", resultArray);
        computeShader.SetTexture(classifyKernel, "_CubemapFaces", cubemapFaces);
        computeShader.SetInt("_KernelRadius", kernelRadius);
        computeShader.SetFloat("_Sigma", sigma);

        computeShader.GetKernelThreadGroupSizes(classifyKernel, out uint threadGroupSizeX, out uint threadGroupSizeY, out uint threadGroupSizeZ);
        int threadGroupsX = Mathf.CeilToInt(cubemap.width / (float)threadGroupSizeX);
        int threadGroupsY = Mathf.CeilToInt(cubemap.height / (float)threadGroupSizeY);
        int threadGroupsZ = 1;

        Debug.Log($"Dispatch Size: ({threadGroupsX}, {threadGroupsY}, {threadGroupsZ})");

        for(int i = 0; i < 6; i++)
        {
            computeShader.SetInt("_Face", i);
            computeShader.Dispatch(classifyKernel, threadGroupsX, threadGroupsY, threadGroupsZ);
        }



        // Copy  RenderTexture to Texture2DArray

        // Create a request and pass in a method to capture the callback
        AsyncGPUReadback.Request(resultArray, 0, 0, resultArray.width, 0, resultArray.height, 0, resultArray.volumeDepth, new Action<AsyncGPUReadbackRequest>
        (
        (AsyncGPUReadbackRequest request) =>
        {
            if (!request.hasError)
            {

                Texture2DArray resultTextures = new Texture2DArray(cubemap.width, cubemap.width, 6, TextureFormat.RGBAFloat, false);

                // Copy the data
                for (var i = 0; i < request.layerCount; i++)
                {
                    resultTextures.SetPixels(request.GetData<Color>(i).ToArray(), i);
                }

                resultTextures.Apply();

                // You'll want to release the no longer required GPU texture somewhere here
                //resultArray.Release();

                // Copy Texture2DArray to Cubemap

                Cubemap resultCubemap = new Cubemap(cubemap.width, TextureFormat.RGBAFloat, false);
                resultCubemap.SetPixels(resultTextures.GetPixels(0), CubemapFace.PositiveX);
                resultCubemap.SetPixels(resultTextures.GetPixels(1), CubemapFace.NegativeX);
                resultCubemap.SetPixels(resultTextures.GetPixels(2), CubemapFace.PositiveY);
                resultCubemap.SetPixels(resultTextures.GetPixels(3), CubemapFace.NegativeY);
                resultCubemap.SetPixels(resultTextures.GetPixels(4), CubemapFace.PositiveZ);
                resultCubemap.SetPixels(resultTextures.GetPixels(5), CubemapFace.NegativeZ);

                //resultCubemap.SetPixels(cubemap.GetPixels(CubemapFace.PositiveX, 0), CubemapFace.PositiveX);

                resultCubemap.Apply(false);


                Debug.Log($"Finished copy cubemap");

                //Shader.SetGlobalTexture("_IrradianceMap", resultCubemap);
                //Shader.SetGlobalTexture("_IrradianceMap", cubemap);


                string path = "Assets/Textures/Environment/ReflectionMap.asset";
                AssetDatabase.DeleteAsset(path);
                AssetDatabase.CreateAsset(resultCubemap, path);

                Debug.Log("Saved 3D asset");
            }
        }
        ));
    }

    private Vector3 CalculateAverage(Texture2D texture)
    {
        Vector3 average = Vector3.zero;
        float max = 0;
        for (int x = 0; x < texture.width; x++)
        {
            for (int y = 0; y < texture.height; y++)
            {
                Color color = texture.GetPixel(x, y);
                average.x += color.r;
                average.y += color.g;
                average.z += color.b;

                if (x == 0 && y == 0)
                    Debug.Log(color);

                max = Mathf.Max(max, color.r);
                max = Mathf.Max(max, color.g);
                max = Mathf.Max(max, color.b);
            }
        }
        Debug.Log("Max: " + max);

        return average / (texture.width * texture.height);
    }

    public void BlurTexture2D()
    {
        Debug.Log($"Environment texture has dimension ({texture.width}, {texture.height})");

        RenderTexture rt = new RenderTexture(texture.width, texture.height, 0, RenderTextureFormat.ARGBFloat);
        rt.Create();
        Graphics.SetRenderTarget(rt);

        switch(filterMode)
        {
            case BlurFilterMode.Bilateral:
                Graphics.Blit(texture, rt, material, (int)Pass.BilateralBlur);
                break;
            case BlurFilterMode.Gaussian:
                Graphics.Blit(texture, rt, material, (int)Pass.GaussianBlur);
                break;
        }

        Vector3 average = CalculateAverage(texture);
        Debug.Log($"Average color: {average.x}, {average.y}, {average.z}");


        Texture2D result = new Texture2D(rt.width, rt.height, TextureFormat.RGBAFloat, false);
        RenderTexture.active = rt;
        result.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        result.Apply();

        Debug.Log($"Result texture has dimension ({result.width}, {result.height})");

        Vector3 averageRT = CalculateAverage(result);
        Debug.Log($"Average RT color: {averageRT.x}, {averageRT.y}, {averageRT.z}");


        //Cubemap cubemap = new Cubemap(256, TextureFormat.RGBAFloat, false);

        //Shader.SetGlobalTexture("_EnvironmentMap", rt);
        //displayImage = rt;

        //SaveTexture2D(renderTarget, texture.format, "blur");
    }

    public void SaveCTSlice(string filename)
    {
        Texture3D current = GameObject.FindFirstObjectByType<VolumeBoundingBox>().GetDataTexture();

        Debug.Log("3D Texture Format: " + current.format);

        Texture2D result = new Texture2D(current.width, current.height, current.format, false, true);

        for (int x = 0; x < current.width; x++)
        {
            for (int y = 0; y < current.height; y++)
            {
                Color color = current.GetPixel(x, y, Slice);

                if (color.r > 0.5f && color.r < 0.7f) // Bone
                {
                    //color = Color.white;
                }
                else
                {
                    //color = Color.black;
                }

                //color = new Color(0.25f, 0.25f, 0.25f, 1);

                /*if(color.r > 0.8f) // Metal
                {
                    color = Color.green;
                }
                else if (color.r > 0.5f && color.r < 0.6f) // Bone
                {
                    color = Color.red;
                }
                else if (color.r > 0.38f && color.r < 0.41f) // Vessels
                {
                    color = Color.yellow;
                }
                else if (color.r > 0.3f && color.r < 0.35f)
                {
                    color = Color.blue;
                }
                else if (color.r < 0.12f)
                {
                    color = Color.black;
                }*/
                //apply the color corresponding to the slice we are on, and the x and y pixel of that slice.
                result.SetPixel(x, y, color);
            }
        }
        result.Apply();


        byte[] bytes = result.EncodeToPNG();
        string dirPath = Application.dataPath + "/Textures/";

        if (!Directory.Exists(dirPath))
        {
            Directory.CreateDirectory(dirPath);
        }
        File.WriteAllBytes(dirPath + filename + ".png", bytes);

        Debug.Log("Saved file to: " + dirPath);
    }

    private void SaveTexture2D(RenderTexture rt, TextureFormat textureFormat, string filename)
    {
        Texture2D result = new Texture2D(rt.width, rt.height, textureFormat, false);

        result.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        result.Apply();

        for (int x = 0; x < rt.width; x++)
        {
            for (int y = 0; y < rt.height; y++)
            {
                Color color = new Color();

                //apply the color corresponding to the slice we are on, and the x and y pixel of that slice.
                result.SetPixel(x, y, color);
            }
        }


        byte[] bytes = result.EncodeToPNG();
        string dirPath = Application.dataPath + "/Textures/";

        if (!Directory.Exists(dirPath))
        {
            Directory.CreateDirectory(dirPath);
        }
        File.WriteAllBytes(dirPath + filename + ".png", bytes);

        Debug.Log("Saved file to: " + dirPath);
    }

    public void BlurTexture3D()
    {
        int width = texture3D.width;
        int height = texture3D.height;
        int depth = 10;// texture3D.depth;

        TextureFormat textureFormat = TextureFormat.RGBA32;

        Texture3D tex3D = new Texture3D(width, height, depth, textureFormat, false);
        tex3D.wrapMode = TextureWrapMode.Clamp;
        tex3D.filterMode = UnityEngine.FilterMode.Trilinear;

        // Create textures fpr the slices
        RenderTexture renderTarget = new RenderTexture(width, width, 0, RenderTextureFormat.ARGB32);
        Graphics.SetRenderTarget(renderTarget);

        Texture2D slice = new Texture2D(width, height, textureFormat, false);

        for (int z = 0; z < depth; z++)
        {
            switch (filterMode)
            {
                case BlurFilterMode.Bilateral:
                    Graphics.Blit(texture, renderTarget, material, (int)Pass.BilateralBlur3D);
                    break;
                case BlurFilterMode.Gaussian:
                    Graphics.Blit(texture, renderTarget, material, (int)Pass.GaussianBlur3D);
                    break;
            }

            slice.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            slice.Apply();

            for (int x = 0; x < width; x++)
            {
                for (int y = 0; y < height; y++)
                {
                    Color color = slice.GetPixel(x, y);

                    //apply the color corresponding to the slice we are on, and the x and y pixel of that slice.
                    tex3D.SetPixel(x, y, z, color);
                }
            }

            byte[] bytes = slice.EncodeToPNG();
            string dirPath = Application.dataPath + "/Textures/";

            if (!Directory.Exists(dirPath))
            {
                Directory.CreateDirectory(dirPath);
            }
            File.WriteAllBytes(dirPath + "blur" + ".png", bytes);

            Debug.Log("Saved file to: " + dirPath);
        }

        Debug.Log(slice.GetPixel(256, 256));
        Debug.Log(tex3D.GetPixel(256, 256, 0));

        // Save 3D texture
        tex3D.Apply();
        string path = "Assets/Textures/blur.asset";
        AssetDatabase.DeleteAsset(path);
        AssetDatabase.CreateAsset(tex3D, path);

        Debug.Log("Saved 3D asset");
    }
}
