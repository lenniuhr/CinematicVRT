using UnityEngine;

[ExecuteInEditMode]
public class TransferFunction : MonoBehaviour
{
    public Gradient gradient = null;

    private const int WIDTH = 1024;

    private void OnEnable()
    {
        UpdateTexture();
    }

    private void OnValidate()
    {
        UpdateTexture();
    }

    private void UpdateTexture()
    {
        if (gradient == null) return;

        Debug.Log("Update texture");

        Texture2D texture = new Texture2D(WIDTH, 1, TextureFormat.ARGB32, false);
        texture.wrapMode= TextureWrapMode.Clamp;
        texture.filterMode= FilterMode.Bilinear;

        for (int i = 0; i < WIDTH; ++i)
        {
            var t = (float)i / WIDTH;
            texture.SetPixel(i, 0, gradient.Evaluate(t));
        }
        texture.Apply(false);

        Shader.SetGlobalTexture("_TransferTex", texture);
    }
}
