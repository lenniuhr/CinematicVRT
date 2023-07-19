using UnityEngine;
using UnityEditor;
using System.IO;

[CustomEditor(typeof(TextureImporter))]
public class TextureImporterEditor : Editor
{
    public override void OnInspectorGUI()
    {
        TextureImporter importer = (TextureImporter)target;

        DrawDefaultInspector();

        string startFolder = Path.GetDirectoryName(Application.dataPath) + "/Data";

        if (GUILayout.Button("Import DICOM Folder"))
        {
            string path = EditorUtility.OpenFolderPanel("Import DICOM Folder", startFolder, "");

            if(path != null && path.Length > 0) importer.ImportDICOMFolder(path);
        }

        if (GUILayout.Button("Import RAW File"))
        {
            string path = EditorUtility.OpenFilePanel("Import RAW File", startFolder, "raw");

            if (path != null && path.Length > 0) importer.ImportRAWFile(path);
        }
    }
}
