using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(VolumeDataset))]
public class VolumeDatasetEditor : Editor
{
    public override void OnInspectorGUI()
    {
        VolumeDataset volumeDataset = (VolumeDataset)target;

        DrawDefaultInspector();
    }
}
