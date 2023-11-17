using UnityEngine;
using System;
using System.Collections.Generic;

public class VolumeClassifier : MonoBehaviour
{
    public Texture2D densityTexture;
    public ComputeShader computeShader;
    public ComputeShader sliceComputeShader;

    [Range(0, 1)] public float FadeOut;
    [Range(0, 1)] public float Slice;
    public bool DisplayGrayscale = false;
    public bool BlurImage = false;
    [Range(1, 8)] public int KernelRadius = 2;
    [Range(0.1f, 10)] public float Sigma = 1;

    public bool AutoUpdate = false;

    private bool isUpdating = false;

    public DensityClass[] densityClasses;
    private ComputeBuffer densityClassesBuffer;

    public RenderTexture displayImage;

    private RenderTexture result;
    private RenderTexture temp;

    public RenderTexture classifyTex;

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
        [Range(0, 1f)]
        public float metallicness;
        [Range(0, 1f)]
        public float roughness;
        [Range(0, 1f)]
        public float reflectance;

        public DensityClass(float min, float max, float gradientLimit, float weight, Color color, float metallicness, float roughness, float reflectance)
        {
            this.min = min;
            this.max = max;
            this.gradientLimit = gradientLimit;
            this.weight = weight;
            this.color = color;
            this.metallicness = metallicness;
            this.roughness = roughness;
            this.reflectance = reflectance;
        }
    };

    private void OnDisable()
    {
        densityClassesBuffer?.Release();
        result?.Release();
        temp?.Release();

        displayImage?.Release();
    }

    private DensityClass[] GetCorrectedDensityClasses()
    {
        if (densityClasses == null) return new DensityClass[0];

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

        Texture3D densityTex = FindObjectOfType<VolumeBoundingBox>().GetDataTexture();
        RenderTexture gradientTex = FindObjectOfType<VolumeBoundingBox>().GetGradientTexture();

        if (densityTex == null || gradientTex == null) return;

        // Initalize
        int classifyKernel = computeShader.FindKernel("Classify");

        computeShader.SetInt("_KernelRadius", KernelRadius);
        computeShader.SetFloat("_Sigma", Sigma);

        float rangeMin = FindObjectOfType<VolumeBoundingBox>().dataset.GetRangeMin();
        float rangeMax = FindObjectOfType<VolumeBoundingBox>().dataset.GetRangeMax();
        Debug.Log($"Value Range: [{rangeMin}, {rangeMax}]");

        computeShader.SetFloat("_RangeMin", rangeMin);
        computeShader.SetFloat("_RangeMax", rangeMax);

        computeShader.SetFloat("_FadeOut", FadeOut);
        computeShader.SetVector("_Dimension", new Vector4(densityTex.width, densityTex.height, densityTex.depth));

        UpdateDensityClasses();

        ShaderHelper.CreateRenderTexture3D(ref result, densityTex.width, densityTex.height, densityTex.depth, "Result", RenderTextureFormat.ARGB32);
        ShaderHelper.CreateRenderTexture3D(ref temp, densityTex.width, densityTex.height, densityTex.depth, "Temp", RenderTextureFormat.ARGB32);

        // Run compute shader
        computeShader.SetTexture(classifyKernel, "_DensityTex3D", densityTex);
        computeShader.SetTexture(classifyKernel, "_GradientTex3D", gradientTex);
        computeShader.SetTexture(classifyKernel, "_Result", result);
        computeShader.SetBuffer(classifyKernel, "_DensityClasses", densityClassesBuffer);

        Debug.Log($"Texture size: ({densityTex.width}, {densityTex.height})...");

        computeShader.GetKernelThreadGroupSizes(classifyKernel, out uint threadGroupSizeX, out uint threadGroupSizeY, out uint threadGroupSizeZ);
        int threadGroupsX = Mathf.CeilToInt(densityTex.width / (float)threadGroupSizeX);
        int threadGroupsY = Mathf.CeilToInt(densityTex.height / (float)threadGroupSizeY);
        int threadGroupsZ = Mathf.CeilToInt(densityTex.depth / (float)threadGroupSizeZ);

        Debug.Log($"Dispatch Size: ({threadGroupsX}, {threadGroupsY}, {threadGroupsZ})");
        computeShader.Dispatch(classifyKernel, threadGroupsX, threadGroupsY, threadGroupsZ);

        if (BlurImage)
        {
            // Run blur
            int blurKernel = computeShader.FindKernel("Blur");

            computeShader.SetTexture(blurKernel, "_DensityTex3D", densityTex);
            computeShader.SetTexture(blurKernel, "_GradientTex3D", gradientTex);
            computeShader.SetBuffer(blurKernel, "_DensityClasses", densityClassesBuffer);


            computeShader.SetTexture(blurKernel, "_Result", temp);
            computeShader.SetTexture(blurKernel, "_PrevResult", result);

            computeShader.Dispatch(blurKernel, threadGroupsX, threadGroupsY, threadGroupsZ);

            classifyTex = temp;
        }
        else
        {
            classifyTex = result;
        }

        Shader.SetGlobalTexture("_ClassifyTex", classifyTex);

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
        RunSliceClassification();

        UpdateDensityClasses();
    }

    private void UpdateDensityClasses()
    {
        ShaderHelper.CreateStructuredBuffer<DensityClass>(ref densityClassesBuffer, densityClasses.Length);
        densityClassesBuffer.SetData(GetCorrectedDensityClasses());

        Shader.SetGlobalBuffer("_DensityClasses", densityClassesBuffer);
    }

    public void RunSliceClassification()
    {
        Texture3D densityTex = FindObjectOfType<VolumeBoundingBox>().GetDataTexture();
        RenderTexture gradientTex = FindObjectOfType<VolumeBoundingBox>().GetGradientTexture();

        if (densityTex == null || gradientTex == null) return;

        float rangeMin = FindObjectOfType<VolumeBoundingBox>().dataset.GetRangeMin();
        float rangeMax = FindObjectOfType<VolumeBoundingBox>().dataset.GetRangeMax();
        Debug.Log($"Value Range: [{rangeMin}, {rangeMax}]");

        UpdateDensityClasses();

        // Set variables
        sliceComputeShader.SetInt("_KernelRadius", KernelRadius);
        sliceComputeShader.SetFloat("_Sigma", Sigma);

        sliceComputeShader.SetFloat("_RangeMin", rangeMin);
        sliceComputeShader.SetFloat("_RangeMax", rangeMax);

        int slice = Mathf.RoundToInt(Slice * (densityTex.depth - 1));
        sliceComputeShader.SetInt("_Slice", slice);
        sliceComputeShader.SetFloat("_FadeOut", FadeOut);
        sliceComputeShader.SetVector("_Dimension", new Vector4(densityTex.width, densityTex.height, densityTex.depth));

        // Initalize
        int classifyKernel = sliceComputeShader.FindKernel("Classify");

        // Create RT
        RenderTexture result = new RenderTexture(densityTex.width, densityTex.height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        result.enableRandomWrite = true;

        // Run compute shader
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

        if(BlurImage)
        {
            RenderTexture prev = new RenderTexture(densityTex.width, densityTex.height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            prev.enableRandomWrite = true;

            int blurKernel = sliceComputeShader.FindKernel("Blur");
            sliceComputeShader.SetTexture(blurKernel, "_DensityTex", densityTex);
            sliceComputeShader.SetTexture(blurKernel, "_GradientTex", gradientTex);
            sliceComputeShader.SetBuffer(blurKernel, "_DensityClasses", densityClassesBuffer);

            sliceComputeShader.SetTexture(blurKernel, "_Result", prev);
            sliceComputeShader.SetTexture(blurKernel, "_PrevFrame", result);

            sliceComputeShader.Dispatch(blurKernel, threadGroupsX, threadGroupsY, threadGroupsZ);

            result.Release();
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
