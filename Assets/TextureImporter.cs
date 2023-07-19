using FellowOakDicom.Imaging.LUT;
using FellowOakDicom.Imaging.Reconstruction;
using FellowOakDicom.Imaging.Render;
using FellowOakDicom.Imaging;
using FellowOakDicom;
using System;
using System.IO;
using UnityEditor;
using UnityEngine;

[ExecuteInEditMode]
public class TextureImporter : MonoBehaviour
{
    public int Width = 512;
    public int Height = 512;
    public DataFormat dataFormat = DataFormat.UInt16;

    public enum DataFormat
    {
        UInt8 = 0,
        UInt16 = 1
    }

    public void ImportRAWFile(string path)
    {
        byte[] pngBytes = File.ReadAllBytes(path);

        Debug.Log(pngBytes.Length);

        int byteSize = 1;
        if (dataFormat == DataFormat.UInt16) byteSize = 2;

        int depth = Mathf.RoundToInt(pngBytes.Length / (Width * Height * byteSize));

        if (pngBytes.Length % (Width * Height * byteSize) != 0)
        {
            Debug.LogError("Dimension mismatch!");
            return;
        }

        // Create texture
        TextureFormat textureFormat = TextureFormat.R16;

        Texture3D tex3D = new Texture3D(Width, Height, depth, textureFormat, false);
        tex3D.wrapMode = TextureWrapMode.Clamp;
        tex3D.filterMode = FilterMode.Bilinear;
        // Convert data

        tex3D.SetPixelData(pngBytes, 0);

        // Save 3D texture
        tex3D.Apply();

        Debug.Log(tex3D.GetPixel(256, 256, 180));

        string assetPath = "Assets/Textures/raw-import.asset";
        AssetDatabase.DeleteAsset(assetPath);
        AssetDatabase.CreateAsset(tex3D, assetPath);

        /*float[,] pixels = new float[size, size];
        for (int i = 0; i < pngBytes.Length; i += 4)
        {
            float value = BitConverter.ToSingle(pngBytes, i);

            int x = (i / 4) % size;
            int y = (i / 4) / size;
            pixels[x, y] = value;
        }
*/
    }

    public void ImportDICOMFolder(string path)
    {
        string[] files = Directory.GetFiles(path, "*", SearchOption.AllDirectories);
        Debug.Log("Found " + files.Length + " files in path " + path);

        // Initialize 3D texture
        int depth = files.Length;

        TextureFormat textureFormat = TextureFormat.RHalf;

        Texture3D tex3D = new Texture3D(Width, Height, depth, textureFormat, false);
        tex3D.wrapMode = TextureWrapMode.Clamp;
        tex3D.filterMode = FilterMode.Bilinear;

        for (int i = 0; i < depth; i++)
        {
            DicomFile dicomFile = DicomFile.Open(files[i]);

            ImageData imageData = new ImageData(dicomFile.Dataset);
            IPixelData pixelData = imageData.Pixels;

            if(pixelData.Width != Width || pixelData.Height != Height)
            {
                Debug.LogError("Dimension mismatch: (" + pixelData.Width + ", " + pixelData.Height + ")!");
                return;
            }

            GrayscaleRenderOptions options = GrayscaleRenderOptions.FromDataset(dicomFile.Dataset);
            ModalityRescaleLUT modalityLUT = new ModalityRescaleLUT(options);

            for (int x = 0; x < Width; x++)
            {
                for (int y = 0; y < Height; y++)
                {
                    float value = Convert.ToSingle(modalityLUT[pixelData.GetPixel(x, y)]);
                    //value = Mathf.InverseLerp(-1024, 24, value);

                    int flippedY = Height - y - 1;
                    tex3D.SetPixel(x, flippedY, i, new Color(value, value, value));
                }
            }
        }

        // Save 3D texture
        tex3D.Apply();
        string assetPath = "Assets/Textures/apple-hu.asset";
        AssetDatabase.DeleteAsset(assetPath);
        AssetDatabase.CreateAsset(tex3D, assetPath);
    }

    private void DICOMToTexture2D(DicomFile dicomFile, Texture2D tex2D)
    {
        ImageData imageData = new ImageData(dicomFile.Dataset);
        IPixelData pixelData = imageData.Pixels;

        Debug.Log("PixelData type: " + pixelData.GetType());

        Debug.Log("Size: (" + pixelData.Width + ", " + pixelData.Height + ")");

        GrayscaleRenderOptions options = GrayscaleRenderOptions.FromDataset(dicomFile.Dataset);
        ModalityRescaleLUT modalityLUT = new ModalityRescaleLUT(options);

        float min = 1000;
        float max = -1000;
        for (int i = 0; i < pixelData.Width; i++)
        {
            for (int j = 0; j < pixelData.Height; j++)
            {
                float value = Convert.ToSingle(modalityLUT[pixelData.GetPixel(i, j)]);
                value = Mathf.InverseLerp(-1024, 24, value);
                tex2D.SetPixel(i, j, new Color(value, value, value));

                min = Mathf.Min(min, value);
                max = Mathf.Max(max, value);
            }
        }

        tex2D.Apply();
    }

    private void SaveTexture2D(DicomFile dicomFile, string filename)
    {
        int width = 512;
        int height = 512;

        Texture2D tex2D = new Texture2D(width, height, TextureFormat.RGBA32, false);

        DICOMToTexture2D(dicomFile, tex2D);

        byte[] bytes = tex2D.EncodeToPNG();
        string dirPath = Application.dataPath + "/Textures/";

        if (!Directory.Exists(dirPath))
        {
            Directory.CreateDirectory(dirPath);
        }
        File.WriteAllBytes(dirPath + filename + ".png", bytes);

        Debug.Log("Saved file to: " + dirPath);
    }
}
