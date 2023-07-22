using FellowOakDicom.Imaging.LUT;
using FellowOakDicom.Imaging.Reconstruction;
using FellowOakDicom.Imaging.Render;
using FellowOakDicom.Imaging;
using FellowOakDicom;
using System.IO;
using System.Threading.Tasks;
using UnityEngine;
using System;

public class DicomImporter
{
    private string folderPath;

    public DicomImporter(string folderPath)
    {
        this.folderPath = folderPath;
    }

    public async Task<VolumeDataset> ImportAsync()
    {
        string[] files = Directory.GetFiles(folderPath, "*", SearchOption.AllDirectories);
        Debug.Log("Found " + files.Length + " files in path " + folderPath);

        int depth = files.Length;

        // Open first file to get dimension
        DicomFile dicomFile = DicomFile.Open(files[0]);
        ImageData imageData = new ImageData(dicomFile.Dataset);
        Debug.Log(imageData.SortingValue);
        IPixelData pixelData = imageData.Pixels;

        int width = pixelData.Width;
        int height = pixelData.Height;

        await Task.Run(() =>
        {
            ushort[] data = new ushort[width * height * depth];

            float min = float.MaxValue;
            float max = float.MinValue;

            int i = 0;
            for (int z = 0; z < depth; z++)
            {
                DicomFile dicomFile = DicomFile.Open(files[z]);

                ImageData imageData = new ImageData(dicomFile.Dataset);
                IPixelData pixelData = imageData.Pixels;

                if (pixelData.Width != width || pixelData.Height != height)
                {
                    Debug.LogError("Dimension mismatch: (" + pixelData.Width + ", " + pixelData.Height + ")!");
                    return;
                }

                GrayscaleRenderOptions options = GrayscaleRenderOptions.FromDataset(dicomFile.Dataset);
                ModalityRescaleLUT modalityLUT = new ModalityRescaleLUT(options);

                for (int x = 0; x < width; x++)
                {
                    for (int y = 0; y < height; y++)
                    {
                        float value = Convert.ToSingle(modalityLUT[pixelData.GetPixel(x, y)]);
                        //float value = Convert.ToSingle(pixelData.GetPixel(x, y));

                        if (value > max) max = value;
                        if (value < min) min = value;

                        data[i] = Mathf.FloatToHalf(value);
                        i++;
                    }
                }
            }
            Debug.Log("[" + min + "/" + max + "]");
        });

        

        return null;
    }
}
