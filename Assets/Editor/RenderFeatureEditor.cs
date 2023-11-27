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
                rf.cinematicSettings.Threshold = EditorGUILayout.Slider("Threshold", rf.cinematicSettings.Threshold, 0, 255);
                rf.cinematicSettings.Accumulate = EditorGUILayout.Toggle("Accumulate", rf.cinematicSettings.Accumulate);
                rf.cinematicSettings.Color = EditorGUILayout.ColorField("Color", rf.cinematicSettings.Color);
                rf.cinematicSettings.SSSRadius = EditorGUILayout.Slider("SSS Radius", rf.cinematicSettings.SSSRadius, 0, 0.2f);
                rf.cinematicSettings.DisneyD = EditorGUILayout.FloatField("Disney D", rf.cinematicSettings.DisneyD);
                break;
            case RenderModeRendererFeature.RenderMode.DELTATRACKING:
                rf.deltaTrackingettings.SamplesPerPixel = EditorGUILayout.IntSlider("Samples Per Pixel", rf.deltaTrackingettings.SamplesPerPixel, 1, 4);
                rf.deltaTrackingettings.MaxSamples = EditorGUILayout.IntSlider("Max Samples", rf.deltaTrackingettings.MaxSamples, 1, 1000);
                rf.deltaTrackingettings.Threshold = EditorGUILayout.Slider("Threshold", rf.deltaTrackingettings.Threshold, 0, 255);
                rf.deltaTrackingettings.SigmaT = EditorGUILayout.FloatField("Sigma T", rf.deltaTrackingettings.SigmaT);
                rf.deltaTrackingettings.Accumulate = EditorGUILayout.Toggle("Accumulate", rf.deltaTrackingettings.Accumulate);
                rf.deltaTrackingettings.Color = EditorGUILayout.ColorField("Color", rf.deltaTrackingettings.Color);
                rf.deltaTrackingettings.Blend = EditorGUILayout.Slider("Blend", rf.deltaTrackingettings.Blend, -1, 1);
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
