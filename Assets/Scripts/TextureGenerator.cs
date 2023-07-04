using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public class TextureGenerator : MonoBehaviour
{
    private Material material;

    // Start is called before the first frame update
    void Start()
    {
        SaveTexture2D();
    }

    private void SaveTexture2D()
    {
        material = CoreUtils.CreateEngineMaterial("Hidden/GaussianBlur");
        material.hideFlags = HideFlags.HideAndDontSave;

        RenderTexture rt = new RenderTexture(256, 256, 0, RenderTextureFormat.RFloat);


        

        //then Save To Disk as PNG
        Texture2D texture = new Texture2D(256, 256, TextureFormat.RFloat, false);

        RenderTexture.active = rt;

        Graphics.SetRenderTarget(rt);
        Graphics.Blit(texture, rt, material);

        texture.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        texture.Apply();

        byte[] bytes = texture.EncodeToPNG();
        string dirPath = Application.dataPath + "/3D Textures/";


        if (!Directory.Exists(dirPath))
        {
            //Directory.CreateDirectory(dirPath);
        }
        File.WriteAllBytes(dirPath + "blur" + ".png", bytes);

        Debug.Log("Saved file to: " + dirPath);
    }

    private void SaveTexture3D()
    {
        RenderTexture rt = new RenderTexture(256, 256, 0, RenderTextureFormat.RFloat);
        rt.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;

        Graphics.SetRenderTarget(rt, 0, CubemapFace.Unknown, 3);

        Texture3D tex3D = new Texture3D(512, 512, 64, TextureFormat.RFloat, false);

        AssetDatabase.CreateAsset(tex3D, "Assets/3D Textures/test.asset");
    }
}
