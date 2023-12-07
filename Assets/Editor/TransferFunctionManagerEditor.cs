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

            TransferFunction2D transferFunction = ScriptableObject.CreateInstance<TransferFunction2D>();
            window.Init(transferFunction);
        }
    }
}
