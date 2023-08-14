using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(TransferFunctionManager))]
public class TransferFunctionManagerEditor : Editor
{
    public override void OnInspectorGUI()
    {
        TransferFunctionManager manager = (TransferFunctionManager)target;

        DrawDefaultInspector();

        if (GUILayout.Button("Edit Transfer Function"))
        {
            TransferFunctionEditorWindow window = (TransferFunctionEditorWindow)EditorWindow.GetWindow(typeof(TransferFunctionEditorWindow), false, "Edit Transfer Function");

            // Create transfer function if missing
            if (manager.TransferFunction == null)
            {
                manager.TransferFunction = ScriptableObject.CreateInstance<TransferFunction>();
                manager.TransferFunction.name = "New Transfer Function";
            }
            window.Init(manager.TransferFunction);
        }
    }
}
