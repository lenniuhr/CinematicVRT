using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;

[CustomEditor(typeof(TextureGenerator))]
public class TextureGeneratorEditor : Editor
{
    public override void OnInspectorGUI()
    {
        TextureGenerator generator = (TextureGenerator)target;

        DrawDefaultInspector();

        if (GUILayout.Button("Blur Texture"))
        {
            generator.BlurTexture2D();
        }

        if (GUILayout.Button("Blur 3D Texture"))
        {
            generator.BlurTexture3D();
        }
    }
}
