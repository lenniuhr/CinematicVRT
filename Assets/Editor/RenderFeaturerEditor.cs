using System;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(VolumeRenderingRendererFeature))]
public class RenderFeatureEditor : Editor
{
    [Serializable]
    public class OctreeSettings
    {
        public float Threshold = 0.2f;
    }

    

    public override void OnInspectorGUI()
    {
        VolumeRenderingRendererFeature rf = (VolumeRenderingRendererFeature)target;

        EditorGUI.BeginChangeCheck();

        rf.renderMode = (VolumeRenderingRendererFeature.RenderMode)EditorGUILayout.EnumPopup("Render Mode", rf.renderMode);

        EditorGUILayout.LabelField("Settings", EditorStyles.boldLabel);

        switch (rf.renderMode)
        {
            case VolumeRenderingRendererFeature.RenderMode.VOLUME:
                rf.settings.StepSize = EditorGUILayout.Slider("Step Size", rf.settings.StepSize, 0.00001f, 0.01f);
                break;
            case VolumeRenderingRendererFeature.RenderMode.OCTREE:
                rf.octreeSettings.OctreeLevel = EditorGUILayout.IntSlider("Octree Level", rf.octreeSettings.OctreeLevel, 0, 7);
                rf.octreeSettings.Threshold = EditorGUILayout.Slider("Threshold", rf.octreeSettings.Threshold, 0, 1);
                break;
        }

        if (EditorGUI.EndChangeCheck())
        {
            Debug.Log("Change");
            rf.Create();
        }
    }
}
