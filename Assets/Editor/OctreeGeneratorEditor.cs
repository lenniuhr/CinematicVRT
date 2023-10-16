using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(OctreeGenerator))]
public class OctreeGeneratorEditor : Editor
{
    public override void OnInspectorGUI()
    {
        OctreeGenerator octreeGenerator = (OctreeGenerator)target;

        DrawDefaultInspector();

        if(GUILayout.Button("Generate Octree"))
        {
            octreeGenerator.RegenerateOctree();
        }
    }
}
