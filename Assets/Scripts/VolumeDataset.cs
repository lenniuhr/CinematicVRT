using System.Data;
using System.Threading.Tasks;
using Unity.Mathematics;
using UnityEngine;

public class VolumeDataset : ScriptableObject
{
    public int width;
    public int height;
    public int depth;

    [HideInInspector][SerializeField]
    private ushort[] data;

    private Texture3D dataTexture;

    public Texture3D GetTexture()
    {
        if(dataTexture != null)
        {
            return dataTexture;
        }
        else
        {
            Texture.allowThreadedTextureCreation = true;
            dataTexture = new Texture3D(width, height, depth, TextureFormat.RHalf, false);
            dataTexture.wrapMode = TextureWrapMode.Clamp;
            dataTexture.filterMode = FilterMode.Bilinear;

            dataTexture.SetPixelData(data, 0);
            dataTexture.Apply();

            return dataTexture;
        }
    }

    public void SetData(ushort[] data)
    {
        this.data = data;
    }
}
