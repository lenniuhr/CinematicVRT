using System.Data;
using System.IO;
using UnityEditor;
using UnityEngine;

public class CVRTEditorFunctions
{
    [MenuItem("CVRT/Import RAW Dataset")]
    private static void ShowRawDatasetImporter()
    {
        string startFolder = Path.GetDirectoryName(Application.dataPath) + "/Data";
        string filePath = EditorUtility.OpenFilePanel("Import RAW Dataset", startFolder, "");

        if (filePath.Length == 0) return;

        if (File.Exists(filePath))
        {
            RawImporterEditorWindow window = (RawImporterEditorWindow)EditorWindow.GetWindow(typeof(RawImporterEditorWindow), false, "Import RAW Dataset");
            window.Init(filePath);
        }
        else
        {
            Debug.LogError("File doesn't exist: " + filePath);
        }
    }

    [MenuItem("CVRT/Import DICOM Dataset")]
    private static async void ImportDicomDataset()
    {
        string startFolder = Path.GetDirectoryName(Application.dataPath) + "/Data";
        string filePath = EditorUtility.OpenFolderPanel("Import DICOM Dataset", startFolder, "");

        if (filePath.Length == 0) return;

        DicomImporter importer = new DicomImporter(filePath);

        VolumeDataset dataset = await importer.ImportAsync();

        if (dataset != null)
        {
            string path = "Assets/Volume Data/" + dataset.datasetName + ".asset";
            AssetDatabase.CreateAsset(dataset, path);

            Debug.Log("Created dataset for " + dataset.datasetName);
        }
    }
}
