using FellowOakDicom;
using System.Data;
using System.IO;
using UnityEditor;
using UnityEngine;

public class CVRTEditorFunctions
{
    [MenuItem("Tools/Import RAW Dataset")]
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

    [MenuItem("Tools/Import DICOM File")]
    private static void ImportDicomFile()
    {
        string startFolder = Path.GetDirectoryName(Application.dataPath) + "/Data";
        string filePath = EditorUtility.OpenFilePanel("Import DICOM File", startFolder, "");

        if (filePath.Length == 0) return;

        DicomImporter importer = new DicomImporter(filePath);

        Texture2D texture = importer.SaveDicomSlice(filePath);

        if (texture != null)
        {
            byte[] bytes = texture.EncodeToPNG();

            string path = "/Textures/DICOM/" + "dicom" + ".png";
            File.WriteAllBytes(Application.dataPath + path, bytes);

            Debug.Log("Created DICOM texture");
        }
    }

    [MenuItem("Tools/Import DICOM Dataset")]
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

            AssetDatabase.AddObjectToAsset(dataset.dataTex, path);

            AssetDatabase.SaveAssets();

            Debug.Log("Added data tex to asset");
        }
    }
}
