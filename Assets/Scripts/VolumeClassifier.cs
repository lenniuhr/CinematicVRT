using UnityEngine;
using System;
using System.Collections.Generic;

public class VolumeClassifier : MonoBehaviour
{
    public Texture2D densityTexture;
    public ComputeShader computeShader;
    public ComputeShader sliceComputeShader;
    [Range(0, 460)]
    public int Slice;
    [Range(0, 50)]
    public int DilateIterations = 3;
    public bool DisplayGrayscale = false;

    [Range(1, 8)] public int KernelRadius = 2;
    [Range(0.1f, 10)] public float Sigma = 1;

    public bool AutoUpdate = false;

    private bool isUpdating = false;

    public DensityClass[] densityClasses;
    private ComputeBuffer densityClassesBuffer;

    public RenderTexture displayImage;
    private RenderTexture result3D;

    [Serializable]
    public struct DensityClass
    {
        public float min;
        public float max;
        [Range(0, 0.5f)]
        public float gradientLimit;
        [Range(0, 1f)]
        public float weight;
        public Color color;

        public DensityClass(float min, float max, float gradientLimit, float weight, Color color)
        {
            this.min = min;
            this.max = max;
            this.gradientLimit = gradientLimit;
            this.weight = weight;
            this.color = color;
        }
    };

    private void OnDisable()
    {
        densityClassesBuffer?.Release();
        result3D?.Release();
        displayImage?.Release();
    }

    private DensityClass[] GetCorrectedDensityClasses()
    {
        DensityClass[] corrected = new DensityClass[densityClasses.Length];
        for(int i = 0; i < densityClasses.Length; i++)
        {
            corrected[i] = densityClasses[i];
            corrected[i].color = corrected[i].color.linear;
        }
        return corrected;
    }

    public void RunClassification3D()
    {
        // Initalize
        int classifyKernel = computeShader.FindKernel("Classify");

        computeShader.SetInt("_KernelRadius", KernelRadius);
        computeShader.SetFloat("_Sigma", Sigma);

        Texture3D densityTex = FindObjectOfType<VolumeBoundingBox>().GetDataTexture();
        Texture3D gradientTex = FindObjectOfType<VolumeBoundingBox>().GetGradientexture();

        if (densityTex == null || gradientTex == null) return;

        ShaderHelper.CreateStructuredBuffer<DensityClass>(ref densityClassesBuffer, densityClasses.Length);
        densityClassesBuffer.SetData(GetCorrectedDensityClasses());

        ShaderHelper.CreateRenderTexture3D(ref result3D, densityTex.width, densityTex.height, densityTex.depth, "Result");

        RenderTexture result2 = ShaderHelper.CreateRenderTexture3D(densityTex.width, densityTex.height, densityTex.depth, "Result2");

        // Run compute shader
        computeShader.SetTexture(classifyKernel, "_DensityTex3D", densityTex);
        computeShader.SetTexture(classifyKernel, "_GradientTex3D", gradientTex);
        computeShader.SetTexture(classifyKernel, "_Result", result3D);
        computeShader.SetBuffer(classifyKernel, "_DensityClasses", densityClassesBuffer);

        Debug.Log($"Texture size: ({densityTex.width}, {densityTex.height})...");

        computeShader.GetKernelThreadGroupSizes(classifyKernel, out uint threadGroupSizeX, out uint threadGroupSizeY, out uint threadGroupSizeZ);
        int threadGroupsX = Mathf.CeilToInt(densityTex.width / (float)threadGroupSizeX);
        int threadGroupsY = Mathf.CeilToInt(densityTex.height / (float)threadGroupSizeY);
        int threadGroupsZ = Mathf.CeilToInt(densityTex.depth / (float)threadGroupSizeZ);

        Debug.Log($"Dispatch Size: ({threadGroupsX}, {threadGroupsY}, {threadGroupsZ})");
        computeShader.Dispatch(classifyKernel, threadGroupsX, threadGroupsY, threadGroupsZ);

        int dilateKernel = computeShader.FindKernel("Dilate");
        computeShader.SetTexture(dilateKernel, "_DensityTex3D", densityTex);
        computeShader.SetTexture(dilateKernel, "_GradientTex3D", gradientTex);
        computeShader.SetBuffer(dilateKernel, "_DensityClasses", densityClassesBuffer);

        // Run dilate
        for (int i = 0; i < DilateIterations * 2; i++)
        {
            if (i % 2 == 0)
            {
                computeShader.SetTexture(dilateKernel, "_Result", result2);
                computeShader.SetTexture(dilateKernel, "_PrevResult", result3D);
            }
            else
            {
                computeShader.SetTexture(dilateKernel, "_Result", result3D);
                computeShader.SetTexture(dilateKernel, "_PrevResult", result2);
            }
            computeShader.Dispatch(dilateKernel, threadGroupsX, threadGroupsY, threadGroupsZ);
        }

        // Release textures and buffers
        result2.Release();

        Shader.SetGlobalTexture("_ClassifyTex", result3D);

        Debug.Log("Finished classification");
    }

    private void OnValidate()
    {
        isUpdating = false;
        if (AutoUpdate && !isUpdating)
        {
            Debug.Log("On Validate");

            isUpdating = true;
            RunClassification3D();
            isUpdating = false;
        }

        Shader.SetGlobalBuffer("_DensityClasses", densityClassesBuffer);
    }

    public void RunSliceClassification()
    {
        Texture3D densityTex = FindObjectOfType<VolumeBoundingBox>().GetDataTexture();
        Texture3D gradientTex = FindObjectOfType<VolumeBoundingBox>().GetGradientexture();

        if (densityTex == null || gradientTex == null) return;

        float minHU = FindObjectOfType<VolumeBoundingBox>().dataset.GetMinValue();
        float maxHU = FindObjectOfType<VolumeBoundingBox>().dataset.GetMaxValue();
        Debug.Log($"Houndsfield Units Range: [{minHU}, {maxHU}]");

        ShaderHelper.CreateStructuredBuffer<DensityClass>(ref densityClassesBuffer, densityClasses.Length); 
        densityClassesBuffer.SetData(densityClasses);

        sliceComputeShader.SetInt("_KernelRadius", KernelRadius);
        sliceComputeShader.SetFloat("_Sigma", Sigma);

        // Initalize
        int classifyKernel = sliceComputeShader.FindKernel("Classify");

        // Create RT
        RenderTexture result = new RenderTexture(densityTex.width, densityTex.height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
        result.enableRandomWrite = true;

        // Run compute shader
        sliceComputeShader.SetInt("_Slice", Slice);
        sliceComputeShader.SetTexture(classifyKernel, "_Result", result);
        sliceComputeShader.SetTexture(classifyKernel, "_DensityTex", densityTex);
        sliceComputeShader.SetTexture(classifyKernel, "_GradientTex", gradientTex);
        sliceComputeShader.SetBuffer(classifyKernel, "_DensityClasses", densityClassesBuffer);

        Debug.Log($"Texture size: ({densityTex.width}, {densityTex.height})...");

        sliceComputeShader.GetKernelThreadGroupSizes(classifyKernel, out uint threadGroupSizeX, out uint threadGroupSizeY, out uint threadGroupSizeZ);
        int threadGroupsX = Mathf.CeilToInt(densityTex.width / (float)threadGroupSizeX);
        int threadGroupsY = Mathf.CeilToInt(densityTex.height / (float)threadGroupSizeY);
        int threadGroupsZ = 1;

        Debug.Log($"Dispatch Size: ({threadGroupsX}, {threadGroupsY}, {threadGroupsZ})");
        sliceComputeShader.Dispatch(classifyKernel, threadGroupsX, threadGroupsY, threadGroupsZ);

        RenderTexture prev = new RenderTexture(densityTex.width, densityTex.height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
        prev.enableRandomWrite = true;

        int dilateKernel = sliceComputeShader.FindKernel("Dilate");
        sliceComputeShader.SetTexture(dilateKernel, "_DensityTex", densityTex);
        sliceComputeShader.SetBuffer(dilateKernel, "_DensityClasses", densityClassesBuffer);

        // Run dilate
        for (int i = 0; i < DilateIterations; i++)
        {
            if(i % 2 == 0)
            {
                sliceComputeShader.SetTexture(dilateKernel, "_Result", prev);
                sliceComputeShader.SetTexture(dilateKernel, "_PrevFrame", result);
            }
            else
            {
                sliceComputeShader.SetTexture(dilateKernel, "_Result", result);
                sliceComputeShader.SetTexture(dilateKernel, "_PrevFrame", prev);
            }
            sliceComputeShader.Dispatch(dilateKernel, threadGroupsX, threadGroupsY, threadGroupsZ);
        }

        if(DilateIterations % 2 == 1)
        {
            result = prev;
        }

        int createImageKernel = sliceComputeShader.FindKernel("CreateImage");
        sliceComputeShader.SetTexture(createImageKernel, "_Result", result);
        sliceComputeShader.SetTexture(createImageKernel, "_DensityTex", densityTex);
        sliceComputeShader.SetBool("_DisplayGrayscale", DisplayGrayscale);
        sliceComputeShader.Dispatch(createImageKernel, threadGroupsX, threadGroupsY, threadGroupsZ);

        displayImage = result;

        /*
        // Copy from RT to texture
        Texture2D save = new Texture2D(densityTex.width, densityTex.height, TextureFormat.RGBA32, false, true);

        RenderTexture.active = result;
        save.ReadPixels(new Rect(0, 0, result.width, result.height), 0, 0);
        save.Apply();

        // Save texture
        byte[] bytes = save.EncodeToPNG();
        string dirPath = Application.dataPath + "/Textures/";
        File.WriteAllBytes(dirPath + "result" + ".png", bytes);

        Debug.Log("Saved file to: " + dirPath);*/
    }
}
