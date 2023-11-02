using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;

[CustomEditor(typeof(VolumeClassifier))]
public class VolumeClassifierEditor : Editor
{
    public override void OnInspectorGUI()
    {
        VolumeClassifier classifier = (VolumeClassifier)target;

        DrawDefaultInspector();

        if (GUILayout.Button("Classify"))
        {
            classifier.RunSliceClassification();
        }

        if (GUILayout.Button("Classify 3D"))
        {
            classifier.RunClassification3D();
        }
    }
}
