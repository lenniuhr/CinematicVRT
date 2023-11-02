using System;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

using FellowOakDicom;
using FellowOakDicom.Imaging;
using FellowOakDicom.Imaging.Reconstruction;
using FellowOakDicom.Imaging.Render;
using FellowOakDicom.Imaging.LUT;

[ExecuteInEditMode]
public class TextureGenerator : MonoBehaviour
{
    public Texture2D texture;

    public Texture3D texture3D;

    private Material material;

    public int Slice;

    public FilterMode filterMode;
    [Range(0, 10)]
    public int kernelRadius;
    [Range(0.001f, 10)]
    public float sigma;
    [Range(0.001f, 10)]
    public float sigmaR;

    public enum FilterMode
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

    

    public void BlurTexture2D()
    {
        RenderTexture renderTarget = new RenderTexture(texture.width, texture.width, 0, RenderTextureFormat.ARGB32);
        Graphics.SetRenderTarget(renderTarget);

        switch(filterMode)
        {
            case FilterMode.Bilateral:
                Graphics.Blit(texture, renderTarget, material, (int)Pass.BilateralBlur);
                break;
            case FilterMode.Gaussian:
                Graphics.Blit(texture, renderTarget, material, (int)Pass.GaussianBlur);
                break;
        }

        SaveTexture2D(renderTarget, texture.format, "blur");
    }

    private void ReadWithImageData()
    {
        //DicomFile dicomFile = DicomFile.Open("C:/Users/lenna/Desktop/DicomConverter/input/2FA0BFF0");
        DicomFile dicomFile = DicomFile.Open("C:/Users/lenna/Desktop/DicomConverter/DICOM/60E51890/834BCAEB/2F95D6C8");
        //DicomFile dicomFile = DicomFile.Open("C:/Users/lenna/Desktop/DicomConverter/input/I103");

        ImageData imageData = new ImageData(dicomFile.Dataset);
        IPixelData iPixelData = imageData.Pixels;

        Debug.Log("PixelData type: " + iPixelData.GetType());

        Debug.Log("Size: (" + iPixelData.Width + ", " + iPixelData.Height + ")");

        GrayscaleRenderOptions options = GrayscaleRenderOptions.FromDataset(dicomFile.Dataset);
        ModalityRescaleLUT modalityLUT = new ModalityRescaleLUT(options);

        float min = 1000;
        float max = -1000;
        for (int i = 0; i < iPixelData.Width; i++)
        {
            for (int j = 0; j < iPixelData.Height; j++)
            {
                float value = Convert.ToSingle(modalityLUT[iPixelData.GetPixel(i, j)]);

                min = Mathf.Min(min, value);
                max = Mathf.Max(max, value);
            }
        }


        //double min = iPixelData.GetMinMax().Minimum;
        //double max = iPixelData.GetMinMax().Maximum;

        Debug.Log("Value range: [" + min + ", " + max + "]");
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

        ReadWithImageData();

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
                case FilterMode.Bilateral:
                    Graphics.Blit(texture, renderTarget, material, (int)Pass.BilateralBlur3D);
                    break;
                case FilterMode.Gaussian:
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
