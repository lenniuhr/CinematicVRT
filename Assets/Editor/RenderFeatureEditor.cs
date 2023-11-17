using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering.Universal;

[CustomEditor(typeof(RenderModeRendererFeature))]
public class RenderFeatureEditor : Editor
{
    public override void OnInspectorGUI()
    {
        RenderModeRendererFeature rf = (RenderModeRendererFeature)target;

        EditorGUI.BeginChangeCheck();

        rf.renderMode = (RenderModeRendererFeature.RenderMode)EditorGUILayout.EnumPopup("Render Mode", rf.renderMode);
        rf.renderPassEvent = (RenderPassEvent)EditorGUILayout.EnumPopup("Render Pass Event", rf.renderPassEvent);

        EditorGUILayout.LabelField("Settings", EditorStyles.boldLabel);

        switch (rf.renderMode)
        {
            case RenderModeRendererFeature.RenderMode.VOLUME:
                rf.settings.StepSize = EditorGUILayout.Slider("Step Size", rf.settings.StepSize, 0.00001f, 0.001f);
                rf.settings.Threshold = EditorGUILayout.Slider("Threshold", rf.settings.Threshold, 0, 1);
                rf.settings.Color = EditorGUILayout.ColorField("Color", rf.settings.Color);
                break;
            case RenderModeRendererFeature.RenderMode.OCTREE:
                rf.octreeSettings.OctreeLevel = EditorGUILayout.IntSlider("Octree Level", rf.octreeSettings.OctreeLevel, 0, 7);
                rf.octreeSettings.Threshold = EditorGUILayout.Slider("Threshold", rf.octreeSettings.Threshold, 0, 1);
                break;
            case RenderModeRendererFeature.RenderMode.RAYTRACE:
                rf.cinematicSettings.Threshold = EditorGUILayout.Slider("Threshold", rf.cinematicSettings.Threshold, 0, 1);
                rf.cinematicSettings.Accumulate = EditorGUILayout.Toggle("Accumulate", rf.cinematicSettings.Accumulate);
                rf.cinematicSettings.Color = EditorGUILayout.ColorField("Color", rf.cinematicSettings.Color);
                break;
        }

        if (GUILayout.Button("Reload"))
        {
            rf.Create();
        }

        if (EditorGUI.EndChangeCheck())
        {
            rf.Create();
        }
    }
}
