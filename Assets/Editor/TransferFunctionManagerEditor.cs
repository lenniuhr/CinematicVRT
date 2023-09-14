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
            if (manager.transferFunction == null)
            {
                manager.transferFunction = ScriptableObject.CreateInstance<TransferFunction>();
                manager.transferFunction.name = "New Transfer Function"; //
            }
            window.Init(manager.transferFunction);
        }
    }
}
