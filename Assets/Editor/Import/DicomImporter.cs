using FellowOakDicom.Imaging.LUT;
using FellowOakDicom.Imaging.Reconstruction;
using FellowOakDicom.Imaging.Render;
using FellowOakDicom.Imaging;
using FellowOakDicom;
using System.IO;
using System.Threading.Tasks;
using UnityEngine;
using System;
using System.Collections.Generic;
using System.Data;

public class DicomImporter
{

    public class DicomSlice
    {
        public string filePath;
        public DicomFile dicomFile;
        public Vector3 position = Vector3.zero;
        public float[] orientation = null;
        public Vector2 pixelSpacing = Vector2.zero;
        public float location = 0;
    }

    private string folderPath;

    public DicomImporter(string folderPath)
    {
        this.folderPath = folderPath;
    }

    public void GetDimensions(List<DicomSlice> slices, out int width, out int height, out int depth)
    {
        ImageData imageData0 = new ImageData(slices[0].dicomFile.Dataset);
        width = imageData0.Pixels.Width;
        height = imageData0.Pixels.Height;
        depth = slices.Count;
    }

    public async Task<VolumeDataset> ImportAsync()
    {
        VolumeDataset dataset = ScriptableObject.CreateInstance<VolumeDataset>();

        ushort[] textureData = null;

        await Task.Run(() =>
        {
            // Load slices and read important tags
            List<DicomSlice> slices = LoadDicomSlices();

            // Sort slices by location
            CalculateSliceLocations(slices);
            slices.Sort((DicomSlice a, DicomSlice b) => { return a.location.CompareTo(b.location); });

            // Convert slices into textureData
            ConvertDicomSlices(slices, dataset, out textureData);

            // Calculate spacing of dataset
            dataset.spacing = new Vector3(
                slices[0].pixelSpacing.x,
                slices[0].pixelSpacing.y,
                Mathf.Abs(slices[slices.Count - 1].location - slices[0].location) / (slices.Count - 1) 
            );
        });

        dataset.dataTex = new Texture3D(dataset.width, dataset.height, dataset.depth, TextureFormat.RHalf, false);
        dataset.dataTex.wrapMode = TextureWrapMode.Clamp;
        dataset.dataTex.filterMode = FilterMode.Bilinear;
        dataset.dataTex.name = "Data Texture";

        dataset.dataTex.SetPixelData(textureData, 0);
        dataset.dataTex.Apply();

        return dataset;
    }

    private List<DicomSlice> LoadDicomSlices()
    {
        List<DicomSlice> slices = new List<DicomSlice>();

        string[] files = Directory.GetFiles(folderPath, "*", SearchOption.AllDirectories);
        Debug.Log("Found " + files.Length + " files in path " + folderPath);

        foreach (string filePath in files)
        {
            slices.Add(ReadDicomFile(filePath));
        }

        return slices;
    }

    private void ConvertDicomSlices(List<DicomSlice> slices, VolumeDataset dataset, out ushort[] textureData)
    {
        Debug.Log($"Converting {slices.Count} DICOM slices");

        dataset.datasetName = Path.GetFileName(Path.GetDirectoryName(slices[0].filePath));
        dataset.dataFormat = DataFormat.UInt16;

        ImageData imageData0 = new ImageData(slices[0].dicomFile.Dataset);
        dataset.width = imageData0.Pixels.Width;
        dataset.height = imageData0.Pixels.Height;
        dataset.depth = slices.Count;

        textureData = new ushort[dataset.width * dataset.height * dataset.depth];
        float min = float.MaxValue;
        float max = float.MinValue;

        for (int z = 0; z < slices.Count; z++)
        {
            DicomSlice slice = slices[z];
            IPixelData pixelData = new ImageData(slice.dicomFile.Dataset).Pixels;

            if (pixelData.Width != dataset.width || pixelData.Height != dataset.height)
            {
                Debug.LogError("Dimension mismatch: (" + pixelData.Width + ", " + pixelData.Height + ")!");
                return;
            }
            GrayscaleRenderOptions options = GrayscaleRenderOptions.FromDataset(slice.dicomFile.Dataset);
            ModalityRescaleLUT modalityLUT = new ModalityRescaleLUT(options);

            for (int y = 0; y < pixelData.Height; y++)
            {
                for (int x = 0; x < pixelData.Width; x++)
                {
                
                    float value = Convert.ToSingle(modalityLUT[pixelData.GetPixel(x, y)]);
                    value = Mathf.Clamp(value, -1024.0f, 3071.0f);

                    if (value > max) max = value;
                    if (value < min) min = value;

                    int dataIndex = (z * dataset.width * dataset.height) + (y * dataset.width) + x;
                    textureData[dataIndex] = Mathf.FloatToHalf(value);
                }
            }
        }
        dataset.minValue = min;
        dataset.maxValue = max;
    }

    private DicomSlice ReadDicomFile(string filePath)
    {
        DicomSlice slice = new DicomSlice();
        DicomFile file = DicomFile.Open(filePath);
        slice.dicomFile = file;
        slice.filePath = filePath;

        if (file.Dataset.Contains(DicomTag.ImagePositionPatient))
        {
            float[] pos = file.Dataset.GetValues<float>(DicomTag.ImagePositionPatient);
            slice.position = new Vector3(pos[0], pos[1], pos[2]);
        }
        if (file.Dataset.Contains(DicomTag.ImageOrientationPatient))
        {
            float[] orientation = file.Dataset.GetValues<float>(DicomTag.ImageOrientationPatient);
            slice.orientation = orientation;
        }
        if (file.Dataset.Contains(DicomTag.PixelSpacing))
        {
            float[] pixelSpacing = file.Dataset.GetValues<float>(DicomTag.PixelSpacing);
            slice.pixelSpacing = new Vector2(pixelSpacing[0], pixelSpacing[1]);
        }
        return slice;
    }

    private void CalculateSliceLocations(List<DicomSlice> slices)
    {
        if (slices.Count == 0 || slices[0].orientation == null)
            return;

        // Get the direction cosines
        float[] cosines = slices[0].orientation;
        // Construct the basis vectors
        Vector3 xBase = new Vector3(cosines[0], cosines[1], cosines[2]);
        Vector3 yBase = new Vector3(cosines[3], cosines[4], cosines[5]);
        Vector3 normal = Vector3.Cross(xBase, yBase);

        for (int i = 0; i < slices.Count; i++)
        {
            Vector3 position = slices[i].position;
            // Project p onto n. d = dot(p,n) / |n| = dot(p,n)
            float distance = Vector3.Dot(position, normal);
            slices[i].location = distance;
        }
    }
}
