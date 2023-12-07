using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using System.Runtime.InteropServices;
using System.Linq;

public class TransferFunction2D : ScriptableObject
{

    [Serializable]
    public struct Line
    {
        public float x1;
        public float x2;
        public float y;

        public Line(float x1, float x2, float y)
        {
            this.x1 = x1;
            this.x2 = x2;
            this.y = y;
        }
    }

    [Serializable]
    public struct Box
    {
        public Color color;
        public Line top;
        public Line bottom;
        public float minAlpha;
        public float maxAlpha;
        public int falloffType;
        public float falloffStrength;

        public Box(Color color, Line top, Line bottom, float minAlpha, float maxAlpha, int falloffType, float falloffStrength)
        {
            this.color = color;
            this.top = top;
            this.bottom = bottom;
            this.minAlpha = minAlpha;
            this.maxAlpha = maxAlpha;
            this.falloffType = falloffType;
            this.falloffStrength = falloffStrength;
        }

        public float GetAlpha(float x, float y)
        {
            float alpha = 0;

            Vector2 barys;
            if (InBounds(x, y, out barys))
            {
                alpha = Mathf.Pow(1.0f - Mathf.Abs(0.5f - barys.x) * 2, 2);
            }
            return alpha;
        }

        public bool InBounds(float x, float y, out Vector2 barys)
        {
            if(y < top.y && y > bottom.y)
            {
                float height01 = (y - bottom.y) / (top.y - bottom.y);
                float leftX = bottom.x1 + (top.x1 - bottom.x1) * height01;
                float rightX = bottom.x2 + (top.x2 - bottom.x2) * height01;

                if (x > leftX && x < rightX)
                {
                    float width01 = (x - leftX) / (rightX - leftX);
                    barys = new Vector2(width01, height01);
                    return true;
                }
            }

            barys = Vector2.zero;
            return false;
        }
    }

    [SerializeField]
    private List<Box> boxes = new List<Box>();

    private const int TEXTURE_WIDTH = 512;
    private const int TEXTURE_HEIGHT = 512;

    public void GenerateBoxes()
    {
        boxes = new List<Box>();

        Line top1 = new Line(0.5f, 0.75f, 0.75f);
        Line bottom1 = new Line(0.35f, 0.65f, 0.45f);
        Box box1 = new Box(Color.red, top1, bottom1, 0, 1, 0, 1);
        boxes.Add(box1);

        Line top2 = new Line(0.3f, 0.55f, 0.85f);
        Line bottom2 = new Line(0.1f, 0.3f, 0.25f);
        Box box2 = new Box(Color.blue, top2, bottom2, 0.5f, 1, 0, 1);
        boxes.Add(box2);

        Line top3 = new Line(0.55f, 0.7f, 0.7f);
        Line bottom3 = new Line(0.35f, 0.65f, 0.1f);
        Box box3 = new Box(Color.green, top3, bottom3, 0, 1, 0, 1);
        boxes.Add(box3);
    }

    public Box GetBoxById(int id)
    {
        return boxes[id];
    }

    public int AddBox()
    {
        Line top = new Line(0.3f, 0.7f, 0.7f);
        Line bottom = new Line(0.3f, 0.7f, 0.3f);
        Box box = new Box(Color.white, top, bottom, 0, 1, 0, 1);
        boxes.Add(box);

        return boxes.Count - 1;
    }

    public void RemoveBox(int index)
    {
        boxes.RemoveAt(index);
    }

    Texture2D texture;
    RenderTexture renderTarget;

    public Texture2D GenerateTextureOnGPU()
    {
        Material material = CoreUtils.CreateEngineMaterial("Hidden/TransferTexture");
        material.hideFlags = HideFlags.HideAndDontSave;

        if(texture == null)
            texture = new Texture2D(TEXTURE_WIDTH, TEXTURE_HEIGHT, TextureFormat.RGBA32, false);
        if(renderTarget == null)
            renderTarget = new RenderTexture(TEXTURE_WIDTH, TEXTURE_HEIGHT, 0, RenderTextureFormat.ARGB32);

        ComputeBuffer boxBuffer = null;
        if (boxes.Count > 0)
        {
            boxBuffer = new ComputeBuffer(boxes.Count, Marshal.SizeOf(typeof(Box)), ComputeBufferType.Structured);

            Box[] boxArray = new Box[boxes.Count];
            for(int i = 0; i < boxes.Count; i++)
            {
                boxArray[i] = boxes[i];
            }
            boxBuffer.SetData(boxArray);

            Shader.SetGlobalBuffer("_BoxBuffer", boxBuffer);
            Shader.SetGlobalInteger("_NumBoxes", boxArray.Length);
        }

        Graphics.SetRenderTarget(renderTarget);

        Graphics.Blit(texture, renderTarget, material, 0);

        texture.ReadPixels(new Rect(0, 0, TEXTURE_WIDTH, TEXTURE_HEIGHT), 0, 0);
        texture.Apply();

        Graphics.SetRenderTarget(null);

        if(boxBuffer != null)
            boxBuffer.Release();

        Shader.SetGlobalTexture("_TransferTex", texture);

        return texture;
    }

    public int Count()
    {
        return boxes.Count;
    }

    public void UpdateBox(int index, Box box)
    {
        boxes[index] = box;
    }
}
