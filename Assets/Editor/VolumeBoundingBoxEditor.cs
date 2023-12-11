using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(VolumeBoundingBox))]
public class VolumeBoundingBoxEditor : Editor
{
    public override void OnInspectorGUI()
    {
        VolumeBoundingBox volumeBoundingBox = (VolumeBoundingBox)target;

        DrawDefaultInspector();

        if (GUILayout.Button("Reload Volume"))
        {
            volumeBoundingBox.Initialize();
        }
    }
}
