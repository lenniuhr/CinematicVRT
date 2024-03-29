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
                rf.settings.StepSize = EditorGUILayout.Slider("Step Size", rf.settings.StepSize, 0.00001f, 0.01f);
                rf.settings.Threshold = EditorGUILayout.Slider("Threshold", rf.settings.Threshold, -1000, 3000);
                rf.settings.Color = EditorGUILayout.ColorField("Color", rf.settings.Color);
                break;
            case RenderModeRendererFeature.RenderMode.OCTREE:
                rf.octreeSettings.OctreeLevel = EditorGUILayout.IntSlider("Octree Level", rf.octreeSettings.OctreeLevel, 0, 7);
                rf.octreeSettings.Threshold = EditorGUILayout.Slider("Threshold", rf.octreeSettings.Threshold, -1000, 3000);
                break;
            case RenderModeRendererFeature.RenderMode.RAYTRACE:
                rf.cinematicSettings.Threshold = EditorGUILayout.Slider("Threshold", rf.cinematicSettings.Threshold, 0, 255);
                rf.cinematicSettings.Accumulate = EditorGUILayout.Toggle("Accumulate", rf.cinematicSettings.Accumulate);
                rf.cinematicSettings.Color = EditorGUILayout.ColorField("Color", rf.cinematicSettings.Color);
                rf.cinematicSettings.SSSRadius = EditorGUILayout.Slider("SSS Radius", rf.cinematicSettings.SSSRadius, 0, 0.2f);
                rf.cinematicSettings.DisneyD = EditorGUILayout.FloatField("Disney D", rf.cinematicSettings.DisneyD);
                break;
            case RenderModeRendererFeature.RenderMode.DELTATRACKING:
                rf.deltaTrackingSettings.SamplesPerPixel = EditorGUILayout.IntSlider("Samples Per Pixel", rf.deltaTrackingSettings.SamplesPerPixel, 1, 4);
                rf.deltaTrackingSettings.MaxSamples = EditorGUILayout.IntSlider("Max Samples", rf.deltaTrackingSettings.MaxSamples, 1, 30000);
                rf.deltaTrackingSettings.Threshold = EditorGUILayout.Slider("Threshold", rf.deltaTrackingSettings.Threshold, 0, 255);
                rf.deltaTrackingSettings.SigmaT = EditorGUILayout.FloatField("Sigma T", rf.deltaTrackingSettings.SigmaT);
                rf.deltaTrackingSettings.Accumulate = EditorGUILayout.Toggle("Accumulate", rf.deltaTrackingSettings.Accumulate);
                rf.deltaTrackingSettings.Color = EditorGUILayout.ColorField("Color", rf.deltaTrackingSettings.Color);
                rf.deltaTrackingSettings.Blend = EditorGUILayout.Slider("Blend", rf.deltaTrackingSettings.Blend, -1, 1);
                rf.deltaTrackingSettings.IncreaseThreshold = EditorGUILayout.Slider("Increase Threshold", rf.deltaTrackingSettings.IncreaseThreshold, 0, 1);
                rf.deltaTrackingSettings.SD = EditorGUILayout.Slider("SD", rf.deltaTrackingSettings.SD, 0, 100);
                rf.deltaTrackingSettings.DefocusStrength = EditorGUILayout.Slider("Diverge Strength", rf.deltaTrackingSettings.DefocusStrength, 0.0f, 0.05f);
                rf.deltaTrackingSettings.FocusDistance = EditorGUILayout.Slider("Focus Distance", rf.deltaTrackingSettings.FocusDistance, 0.1f, 10f);
                rf.deltaTrackingSettings.PTerminate = EditorGUILayout.Slider("Termination probability", rf.deltaTrackingSettings.PTerminate, 0, 1);
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
