using UnityEditor;
using UnityEngine;

public class RawImporterEditorWindow : EditorWindow
{
    private string file;
    private int dimX = 256;
    private int dimY = 256;
    private int dimZ = 256;
    private DataFormat dataFormat = DataFormat.UInt8;
    private Vector3 spacing = Vector3.one;
    private float valueOffset = 0;

    private void CreateGUI()
    {
        maxSize = new Vector2(450, 200);
    }

    public void Init(string file)
    {
        this.file = file;
    }

    private void OnGUI()
    {
        dimX = EditorGUILayout.IntField("X Dimension", dimX);
        dimY = EditorGUILayout.IntField("Y Dimension", dimY);
        dimZ = EditorGUILayout.IntField("Z Dimension", dimZ);
        dataFormat = (DataFormat)EditorGUILayout.EnumPopup("Data Format", dataFormat);
        spacing = EditorGUILayout.Vector3Field("Spacing", spacing);
        valueOffset = EditorGUILayout.FloatField("Value Offset", valueOffset);

        if (GUILayout.Button("Import"))
        {
            ImportDatasetAsync();
        }
        if (GUILayout.Button("Cancel"))
        {
            this.Close();
        }
    }

    private async void ImportDatasetAsync()
    {
        RawImporter importer = new RawImporter(file, dimX, dimY, dimZ, dataFormat, valueOffset);
        VolumeDataset dataset = await importer.ImportDataAsync();
        dataset.spacing = spacing;

        if (dataset != null)
        {
            string path = "Assets/Volume Data/" + dataset.datasetName + ".asset";
            AssetDatabase.CreateAsset(dataset, path);

            Debug.Log("Created dataset for " + dataset.datasetName);

            AssetDatabase.AddObjectToAsset(dataset.dataTex, path);

            AssetDatabase.SaveAssets();

            Debug.Log("Added data tex to asset");

            this.Close();
        }
    }
}
