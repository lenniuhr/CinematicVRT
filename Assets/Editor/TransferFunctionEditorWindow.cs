using Codice.Client.Commands.TransformerRule;
using System.Collections.Generic;
using System.Data;
using UnityEditor;
using UnityEngine;

public class TransferFunctionEditorWindow : EditorWindow
{
    private Texture2D texture;

    private TransferFunction transferFunction;

    private Color UNITY_BLUE = new Color(58 / 255.0f, 115 / 255.0f, 175 / 255.0f);

    private const int MARGIN = 10;

    private string tfName;

    public async void Init(TransferFunction transferFunction)
    {
        textureWidth = position.width - 2 * MARGIN;
        textureHeight = textureWidth / 2;
        this.transferFunction = transferFunction;
        tfName = transferFunction.name;

        // Setup UI boxes
        guiBoxes = new List<ResizableBox>();
        for (int index = 0; index < transferFunction.Count();  index++)
        {
            guiBoxes.Add(new ResizableBox(transferFunction, index, circle, textureWidth, textureHeight, MARGIN));
        }
        SelectAnyBox();

        // Init volume
        VolumeBoundingBox volumeBB = FindFirstObjectByType<VolumeBoundingBox>();
        Debug.Log(volumeBB.dataset.datasetName);

        // Placeholder until histogram is generated
        texture = new Texture2D(1, 1, TextureFormat.RGBA32, false);
        texture = await volumeBB.dataset.GetHistogram();
    }

    private void CreateGUI()
    {
        circle = EditorGUIUtility.Load("Assets/Textures/UI/CircleIcon.psd") as Texture2D;
        minSize = new Vector2(500, 500);
    }

    private void OnEnable()
    {
        guiBoxes = new List<ResizableBox>();
    }

    private Texture2D circle;

    private float textureWidth;
    private float textureHeight;

    private List<ResizableBox> guiBoxes; 

    ResizableBox selectedBox = null;

    private void OnGUI()
    {
        Vector2 mousePos = new Vector2(Event.current.mousePosition.x, Event.current.mousePosition.y);

        // Handle resize
        if (textureWidth != position.width - 2 * MARGIN || textureHeight != textureWidth / 2)
        {
            textureWidth = position.width - 2 * MARGIN;
            textureHeight = textureWidth / 2;
            foreach (ResizableBox box in guiBoxes)
            {
                box.Resize(textureWidth, textureHeight);
            }
        }

        // Draw background texture
        Rect textureRect = new Rect(MARGIN, MARGIN, textureWidth, textureHeight);

        GUI.DrawTexture(textureRect, texture, ScaleMode.StretchToFill, true, 0, Color.white, 0, 6);
        GUI.DrawTexture(textureRect, transferFunction.GeneratePreviewTextureOnGPU(), ScaleMode.StretchToFill, true, 0, Color.white, 0, 6);

        // Handle Input
        if (Event.current.type == EventType.MouseDown)
        {
            foreach (ResizableBox box in guiBoxes)
            {
                if (box.Intersect(mousePos))
                {
                    selectedBox = box;
                    break;
                }
                
            }
        }

        if (Event.current.type == EventType.MouseUp)
        {
            
        }

        if (Event.current.type == EventType.MouseDrag)
        {
            if(selectedBox != null)
            {
                selectedBox.HandleMouseDrag(mousePos);
            }
        }


        // Draw Boxes and handle hovering
        bool overlap = false;
        foreach (ResizableBox box in guiBoxes)
        {
            Color boxcolor = (box == selectedBox) ? UNITY_BLUE : Color.gray;
            box.Draw(boxcolor);
            if(!overlap)
                overlap= box.AddCursorIcons(mousePos);
        }

        Rect colorRect = new Rect(MARGIN, textureHeight + MARGIN * 2, textureWidth, 150);
        GUI.BeginGroup(colorRect);

        EditorGUILayout.BeginHorizontal(GUILayout.MaxWidth(textureWidth - 5));

        EditorGUILayout.BeginVertical();

        GUIContent nameLabel = new GUIContent("Name");
        EditorGUIUtility.labelWidth = EditorStyles.label.CalcSize(nameLabel).x + 10;
        tfName = EditorGUILayout.TextField(nameLabel, tfName);

        GUILayout.Space(5);

        bool renameTF = tfName != transferFunction.name;
        bool newTF = !AssetDatabase.Contains(transferFunction);
        bool dirtyTF = EditorUtility.IsDirty(transferFunction);
        GUI.enabled = newTF || renameTF || dirtyTF;
        if (GUILayout.Button("Save Changes"))
        {
            if (newTF)
            {
                string path = "Assets/Volume Data/" + tfName + ".asset";
                AssetDatabase.CreateAsset(transferFunction, path);
            }
            else if(renameTF)
            {
                EditorUtility.SetDirty(transferFunction);
                AssetDatabase.SaveAssetIfDirty(transferFunction);

                string path = AssetDatabase.GetAssetPath(transferFunction);
                AssetDatabase.RenameAsset(path, tfName);
            }
        }
        GUI.enabled = true;

        GUILayout.Space(5);

        if (GUILayout.Button("Add New Box"))
        {
            int newIndex = transferFunction.AddBox();
            ResizableBox newBox = new ResizableBox(transferFunction, newIndex, circle, textureWidth, textureHeight, MARGIN);
            guiBoxes.Add(newBox);
            selectedBox = newBox;
        }

        GUILayout.Space(5);

        GUI.enabled = (selectedBox != null);
        if (GUILayout.Button("Remove Selected Box"))
        {
            transferFunction.RemoveBox(selectedBox.index);
            guiBoxes.Remove(selectedBox);
            foreach(ResizableBox box in guiBoxes)
            {
                if(box.index > selectedBox.index)
                {
                    box.index--;
                }
            }
            SelectAnyBox();
        }
        GUI.enabled = true;

        EditorGUILayout.EndVertical();

        if (selectedBox != null)
        {
            EditorGUILayout.Space(50);

            EditorGUILayout.BeginVertical();

            GUIContent colorLabel = new GUIContent("Color");
            EditorGUIUtility.labelWidth = EditorStyles.label.CalcSize(colorLabel).x + 10;
            selectedBox.color = EditorGUILayout.ColorField(colorLabel, selectedBox.color, true, false, false);

            GUILayout.Space(5);

            EditorGUILayout.BeginHorizontal();

            GUIContent minAlphaLabel = new GUIContent("Min Alpha");
            EditorGUIUtility.labelWidth = EditorStyles.label.CalcSize(minAlphaLabel).x + 10;
            selectedBox.minAlpha = EditorGUILayout.Slider(minAlphaLabel, selectedBox.minAlpha, 0, 1);

            GUILayout.Space(20);

            GUIContent maxAlphaLabel = new GUIContent("Max Alpha");
            EditorGUIUtility.labelWidth = EditorStyles.label.CalcSize(maxAlphaLabel).x + 10;
            selectedBox.maxAlpha = EditorGUILayout.Slider(maxAlphaLabel, selectedBox.maxAlpha, 0, 1);

            EditorGUILayout.EndHorizontal();

            GUILayout.Space(5);

            EditorGUILayout.BeginHorizontal();

            GUIContent falloffTypeLabel = new GUIContent("Falloff Type");
            EditorGUIUtility.labelWidth = EditorStyles.label.CalcSize(falloffTypeLabel).x + 10;
            selectedBox.falloffType = (ResizableBox.FalloffType)EditorGUILayout.EnumPopup(falloffTypeLabel, selectedBox.falloffType);

            GUILayout.Space(20);

            GUIContent falloffStrengthLabel = new GUIContent("Falloff Strength");
            EditorGUIUtility.labelWidth = EditorStyles.label.CalcSize(falloffStrengthLabel).x + 10;
            selectedBox.falloffStrength = EditorGUILayout.Slider(falloffStrengthLabel, selectedBox.falloffStrength, 1, 8);

            EditorGUILayout.EndHorizontal();

            EditorGUILayout.EndVertical();

            selectedBox.UpdateTFBox();
        }

        EditorGUILayout.EndHorizontal();

        GUI.EndGroup();

        Rect anotherRect = new Rect(MARGIN, textureHeight + 3 * MARGIN + 150, 200, 100);
        GUI.DrawTexture(anotherRect,new Texture2D(1, 1), ScaleMode.StretchToFill, true, 0, Color.white, 0, 3);
        GUI.DrawTexture(anotherRect, transferFunction.GeneratePreviewTextureOnGPU(), ScaleMode.StretchToFill, true, 0, Color.white, 0, 3);


        Repaint();
    }

    private void SelectAnyBox()
    {
        if(guiBoxes.Count > 0)
        {
            selectedBox = guiBoxes[0];
        }
        else
        {
            selectedBox = null;
        }
    }

    private void DrawControlPoints(Vector2 coords)
    {
        Rect controlPointBox = new Rect(coords.x - 6, coords.y - 6, 12, 12);
        GUI.Box(controlPointBox, circle, GUIStyle.none);
        EditorGUIUtility.AddCursorRect(controlPointBox, MouseCursor.SlideArrow);
    }

    public Vector2 TransferToEditorCoord(float x, float y)
    {
        float editorX = MARGIN + (x * textureWidth);
        float editorY = MARGIN + ((1 - y) * textureHeight);

        return new Vector2(editorX, editorY);
    }

    public Vector2 EditorToTextureCoord(Vector2 editorCoord)
    {
        float texCoordX = Mathf.Clamp01((editorCoord.x - MARGIN) / textureWidth);
        float texCoordY = Mathf.Clamp01(-(editorCoord.y - MARGIN) / textureHeight + 1);

        return new Vector2(texCoordX, texCoordY);
    }
}
