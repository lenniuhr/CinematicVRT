using System.Collections;
using System.Collections.Generic;
using System.Drawing.Printing;
using UnityEditor;
using UnityEngine;

public class ResizableBox
{
    public enum IntersectionType
    {
        None,
        TopLeftCorner,
        TopRightCorner,
        BottomLeftCorner,
        BottomRightCorner,
        TopEdge,
        BottomEdge,
        LeftEdge,
        RightEdge,
        Area
    }
    public enum FalloffType
    {
        Horizontal = 0,
        Spherical = 1,
    }

    public Color color;
    public float minAlpha;
    public float maxAlpha;

    public FalloffType falloffType;
    public float falloffStrength;

    private TransferFunction transferFunction;
    public int index;
    private Texture2D circle;

    //  Corners
    public Rect topLeftRect;
    public Rect topRightRect;
    public Rect bottomLeftRect;
    public Rect bottomRightRect;

    // Top / Bottom
    public Rect topRect;
    public Rect bottomRect;

    // Center
    public Rect centerRect;

    private Vector2 topLeft;
    private Vector2 topRight;
    private Vector2 bottomLeft;
    private Vector2 bottomRight;


    private float textureWidth;
    private float textureHeight;
    private float margin;

    private const int CORNER_HITBOX = 10;
    private const int CORNER_ICON_RADIUS = 8;

    private IntersectionType intersection;
    private Vector2 clickOffsetTopLeft;
    private Vector2 clickOffsetTopRight;
    private Vector2 clickOffsetBottomLeft;
    private Vector2 clickOffsetBottomRight;

    public ResizableBox(TransferFunction transferFunction, int index, Texture2D circle, float textureWidth, float textureHeight, float margin)
    {
        this.transferFunction = transferFunction;
        this.index = index;
        this.circle = circle;
        this.margin = margin;

        Resize(textureWidth, textureHeight);
    }

    public void Resize(float textureWidth, float textureHeight)
    {
        this.textureWidth = textureWidth;
        this.textureHeight = textureHeight;

        Rescale();
    }

    public void Rescale()
    {
        TransferFunction.Box tfBox = transferFunction.GetBoxById(index);
        color = tfBox.color;

        topLeft = TextureToEditorCoord(tfBox.top.x1, tfBox.top.y);
        topRight = TextureToEditorCoord(tfBox.top.x2, tfBox.top.y);
        bottomLeft = TextureToEditorCoord(tfBox.bottom.x1, tfBox.bottom.y);
        bottomRight = TextureToEditorCoord(tfBox.bottom.x2, tfBox.bottom.y);

        minAlpha = tfBox.minAlpha;
        maxAlpha= tfBox.maxAlpha;
        falloffType = (FalloffType)tfBox.falloffType;
        falloffStrength = tfBox.falloffStrength;

        UpdateRects();
    }

    private void UpdateRects()
    {
        topLeftRect = new Rect(topLeft.x - CORNER_ICON_RADIUS, topLeft.y - CORNER_ICON_RADIUS, 2 * CORNER_ICON_RADIUS, 2 * CORNER_ICON_RADIUS);
        topRightRect = new Rect(topRight.x - CORNER_ICON_RADIUS, topRight.y - CORNER_ICON_RADIUS, 2 * CORNER_ICON_RADIUS, 2 * CORNER_ICON_RADIUS);
        bottomLeftRect = new Rect(bottomLeft.x - CORNER_ICON_RADIUS, bottomLeft.y - CORNER_ICON_RADIUS, 2 * CORNER_ICON_RADIUS, 2 * CORNER_ICON_RADIUS);
        bottomRightRect = new Rect(bottomRight.x - CORNER_ICON_RADIUS, bottomRight.y - CORNER_ICON_RADIUS, 2 * CORNER_ICON_RADIUS, 2 * CORNER_ICON_RADIUS);

        float left = Mathf.Min(topLeft.x, bottomLeft.x) + CORNER_ICON_RADIUS;
        float right = Mathf.Max(topRight.x, bottomRight.x) - CORNER_ICON_RADIUS;
        centerRect = new Rect(left, topLeft.y + CORNER_ICON_RADIUS, right - left, bottomLeft.y - topLeft.y - 2 * CORNER_HITBOX);
    }

    public Vector2 TextureToEditorCoord(float x, float y)
    {
        float editorX = margin + (x * textureWidth);
        float editorY = margin + ((1 - y) * textureHeight);
        return new Vector2(editorX, editorY);
    }
    public Vector2 EditorToTextureCoord(Vector2 editorCoord)
    {
        float texCoordX = Mathf.Clamp01((editorCoord.x - margin) / textureWidth);
        float texCoordY = Mathf.Clamp01(-(editorCoord.y - margin) / textureHeight + 1);

        return new Vector2(texCoordX, texCoordY);
    }

    public bool AddCursorIcons(Vector2 mousePos)
    {
        if (IntersectCorner(topLeft, mousePos))
        {
            Add22CursorRect(mousePos, MouseCursor.MoveArrow);
            return true;
        }
        else if (IntersectCorner(topRight, mousePos))
        {
            Add22CursorRect(mousePos, MouseCursor.MoveArrow);
            return true;
        }
        else if (IntersectCorner(bottomLeft, mousePos))
        {
            Add22CursorRect(mousePos, MouseCursor.MoveArrow);
            return true;
        }
        else if (IntersectCorner(bottomRight, mousePos))
        {
            Add22CursorRect(mousePos, MouseCursor.MoveArrow);
            return true;
        }
        else if(IntersectVertical(topLeft, bottomLeft, mousePos))
        {
            Add22CursorRect(mousePos, MouseCursor.ResizeHorizontal);
            return true;
        }
        else if (IntersectVertical(topRight, bottomRight, mousePos))
        {
            Add22CursorRect(mousePos, MouseCursor.ResizeHorizontal);
            return true;
        }
        else if (IntersectHorizontal(topLeft, topRight, mousePos))
        {
            Add22CursorRect(mousePos, MouseCursor.ResizeVertical);
            return true;
        }
        else if (IntersectHorizontal(bottomLeft, bottomRight, mousePos))
        {
            Add22CursorRect(mousePos, MouseCursor.ResizeVertical);
            return true;
        }
        else if (IntersectCenter(mousePos))
        {
            Add22CursorRect(mousePos, MouseCursor.Pan);
            return true;
        }
        return false;
    }

    private bool IntersectCenter(Vector2 mousePos)
    {
        if (mousePos.y >= topLeft.y + CORNER_HITBOX && mousePos.y <= bottomLeft.y - CORNER_HITBOX)
        {
            float y01 = Mathf.InverseLerp(topLeft.y, bottomLeft.y, mousePos.y);
            float intersectionXLeft = Mathf.Lerp(topLeft.x, bottomLeft.x, y01);
            float intersectionXRight = Mathf.Lerp(topRight.x, bottomRight.x, y01);

            if (mousePos.x >= intersectionXLeft + CORNER_HITBOX && mousePos.x <= intersectionXRight - CORNER_HITBOX)
            {
                Add22CursorRect(mousePos, MouseCursor.Pan);
                return true;
            }
        }
        return false;
    }

    private bool IntersectVertical(Vector2 top, Vector2 bottom, Vector2 mousePos)
    {
        if (mousePos.y >= top.y + CORNER_HITBOX && mousePos.y <= bottom.y - CORNER_HITBOX)
        {
            float y01 = Mathf.InverseLerp(top.y, bottom.y, mousePos.y);
            float intersectionX = Mathf.Lerp(top.x, bottom.x, y01);

            if (mousePos.x >= intersectionX - CORNER_HITBOX && mousePos.x <= intersectionX + CORNER_HITBOX)
            {
                return true;
            }
        }
        return false;
    }

    private bool IntersectHorizontal(Vector2 left, Vector2 right, Vector2 mousePos)
    {
        if (mousePos.y >= left.y - CORNER_HITBOX && mousePos.y <= left.y + CORNER_HITBOX)
        {
            if (mousePos.x >= left.x - CORNER_HITBOX && mousePos.x <= right.x + CORNER_HITBOX)
            {
                return true;
            }
        }
        return false;
    }

    public bool IntersectCorner(Vector2 corner, Vector2 mousePos)
    {
        if (mousePos.y >= corner.y - CORNER_HITBOX && mousePos.y <= corner.y + CORNER_HITBOX)
        {
            if (mousePos.x >= corner.x - CORNER_HITBOX && mousePos.x <= corner.x + CORNER_HITBOX)
            {
                return true;
            }
        }
        return false;
    }

    private void Add22CursorRect(Vector2 mousePos, MouseCursor mouseCursor)
    {
        Rect mouse = new Rect(mousePos.x - 10, mousePos.y - 10, 20, 20);
        EditorGUIUtility.AddCursorRect(mouse, mouseCursor);
    }

    public void Draw(Color color)
    {
        // Draw Circles
        Color oldColor = GUI.contentColor;
        GUI.contentColor = color;
        GUI.Box(topLeftRect, circle, GUIStyle.none);
        GUI.Box(topRightRect, circle, GUIStyle.none);
        GUI.Box(bottomLeftRect, circle, GUIStyle.none);
        GUI.Box(bottomRightRect, circle, GUIStyle.none);
        GUI.contentColor = oldColor;

        // Draw Lines
        Handles.BeginGUI();
        Handles.color = color;
        Handles.DrawLine(topLeft, topRight);
        Handles.DrawLine(topRight, bottomRight);
        Handles.DrawLine(bottomRight, bottomLeft);
        Handles.DrawLine(bottomLeft, topLeft);
        Handles.EndGUI();
    }

    private void SetClickOffsets(Vector2 mousePos)
    {
        clickOffsetTopLeft = topLeft - mousePos;
        clickOffsetTopRight = topRight - mousePos;
        clickOffsetBottomLeft = bottomLeft - mousePos;
        clickOffsetBottomRight = bottomRight - mousePos;
    }

    public bool Intersect(Vector2 mousePos)
    {
        SetClickOffsets(mousePos);

        if (IntersectCorner(topLeft, mousePos))
        {
            intersection = IntersectionType.TopLeftCorner;
            return true;
        }
        else if (IntersectCorner(topRight, mousePos))
        {
            intersection = IntersectionType.TopRightCorner;
            return true;
        }
        else if (IntersectCorner(bottomLeft, mousePos))
        {
            intersection = IntersectionType.BottomLeftCorner;
            return true;
        }
        else if (IntersectCorner(bottomRight, mousePos))
        {
            intersection = IntersectionType.BottomRightCorner;
            return true;
        }
        else if (IntersectVertical(topLeft, bottomLeft, mousePos))
        {
            intersection = IntersectionType.LeftEdge;
            return true;
        }
        else if (IntersectVertical(topRight, bottomRight, mousePos))
        {
            intersection = IntersectionType.RightEdge;
            return true;
        }
        else if (IntersectHorizontal(topLeft, topRight, mousePos))
        {
            intersection = IntersectionType.TopEdge;
            return true;
        }
        else if (IntersectHorizontal(bottomLeft, bottomRight, mousePos))
        {
            intersection = IntersectionType.BottomEdge;
            return true;
        }
        else if (IntersectCenter(mousePos))
        {
            intersection = IntersectionType.Area;
            return true;
        }
        intersection = IntersectionType.None;
        return false;
    }
    public void HandleMouseDrag(Vector2 mousePos)
    {
        Vector2 targetTopLeft = mousePos + clickOffsetTopLeft;
        Vector2 targetTopRight = mousePos + clickOffsetTopRight;
        Vector2 targetBottomLeft = mousePos + clickOffsetBottomLeft;
        Vector2 targetBottomRight = mousePos + clickOffsetBottomRight;

        switch (intersection)
        {
            case IntersectionType.TopLeftCorner:
                topLeft = ClampToWindow(targetTopLeft);
                topLeft.y = Mathf.Min(topLeft.y, bottomLeft.y);
                topLeft.x = Mathf.Min(topLeft.x, topRight.x);
                topRight.y = topLeft.y;
                break;
            case IntersectionType.TopRightCorner:
                topRight = ClampToWindow(targetTopRight);
                topRight.y = Mathf.Min(topRight.y, bottomRight.y);
                topRight.x = Mathf.Max(topRight.x, topLeft.x);
                topLeft.y = topRight.y;
                break;
            case IntersectionType.BottomLeftCorner:
                bottomLeft = ClampToWindow(targetBottomLeft);
                bottomLeft.y = Mathf.Max(bottomLeft.y, topLeft.y);
                bottomLeft.x = Mathf.Min(bottomLeft.x, bottomRight.x);
                bottomRight.y = bottomLeft.y;
                break;
            case IntersectionType.BottomRightCorner:
                bottomRight = ClampToWindow(targetBottomRight);
                bottomRight.y = Mathf.Max(bottomRight.y, topRight.y);
                bottomRight.x = Mathf.Max(bottomRight.x, bottomLeft.x);
                bottomLeft.y = bottomRight.y;
                break;
            case IntersectionType.LeftEdge:
                topLeft = ClampToWindow(targetTopLeft);
                topLeft.x = Mathf.Min(topLeft.x, topRight.x);
                bottomLeft = ClampToWindow(targetBottomLeft);
                bottomLeft.x = Mathf.Min(bottomLeft.x, bottomRight.x);
                topRight.y = topLeft.y;
                bottomRight.y = bottomLeft.y;
                break;
            case IntersectionType.RightEdge:
                topRight = ClampToWindow(targetTopRight);
                topRight.x = Mathf.Max(topRight.x, topLeft.x);
                bottomRight = ClampToWindow(targetBottomRight);
                bottomRight.x = Mathf.Max(bottomRight.x, bottomLeft.x);
                topLeft.y = topRight.y;
                bottomLeft.y = bottomRight.y;
                break;
            case IntersectionType.TopEdge:
                topLeft = ClampToWindow(targetTopLeft);
                topLeft.y = Mathf.Min(topLeft.y, bottomLeft.y);
                topRight = ClampToWindow(targetTopRight);
                topRight.y = Mathf.Min(topRight.y, bottomRight.y);
                break;
            case IntersectionType.BottomEdge:
                bottomLeft = ClampToWindow(targetBottomLeft);
                bottomLeft.y = Mathf.Max(bottomLeft.y, topLeft.y);
                bottomRight = ClampToWindow(targetBottomRight);
                bottomRight.y = Mathf.Max(bottomRight.y, topRight.y);
                break;
            case IntersectionType.Area:
                topLeft = ClampToWindow(targetTopLeft);
                topRight = ClampToWindow(targetTopRight);
                bottomLeft = ClampToWindow(targetBottomLeft);
                bottomRight = ClampToWindow(targetBottomRight);
                break;
            default:
                break;
        }
        UpdateRects();
        UpdateTFBox();
    }

    private Vector2 ClampToWindow(Vector2 v)
    {
        return new Vector2(Mathf.Clamp(v.x, margin, textureWidth + margin), Mathf.Clamp(v.y, margin, textureHeight + margin));
    }

    private float ClampXToWindow(float x)
    {
        return Mathf.Clamp(x, margin, textureWidth + margin);
    }

    private float ClampYToWindow(float y)
    {
        return Mathf.Clamp(y, margin, textureHeight + margin);
    }

    public void UpdateTFBox()
    {
        Vector2 topLeftTex = EditorToTextureCoord(topLeft);
        Vector2 topRightTex = EditorToTextureCoord(topRight);
        Vector2 bottomLeftTex = EditorToTextureCoord(bottomLeft);
        Vector2 bottomRightTex = EditorToTextureCoord(bottomRight);

        TransferFunction.Box tfBox = new TransferFunction.Box();

        tfBox.color = color;

        tfBox.top = new TransferFunction.Line();
        tfBox.top.x1 = topLeftTex.x;
        tfBox.top.x2 = topRightTex.x;
        tfBox.top.y = topLeftTex.y;

        tfBox.bottom = new TransferFunction.Line();
        tfBox.bottom.x1 = bottomLeftTex.x;
        tfBox.bottom.x2 = bottomRightTex.x;
        tfBox.bottom.y = bottomLeftTex.y;

        tfBox.minAlpha = minAlpha; 
        tfBox.maxAlpha = maxAlpha;
        tfBox.falloffType = (int)falloffType;
        tfBox.falloffStrength = falloffStrength;

        transferFunction.UpdateBox(index, tfBox);
    }
}
