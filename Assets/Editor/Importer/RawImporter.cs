using System;
using System.IO;
using System.Threading.Tasks;
using UnityEngine;

public class RawImporter
{
    private string filePath;
    private int width = 256;
    private int height = 256;
    private int depth;
    private DataFormat dataFormat;

    public RawImporter(string filePath, int width, int height, int depth, DataFormat dataFormat)
    {
        this.filePath = filePath;
        this.width = width;
        this.height = height;
        this.depth = depth;
        this.dataFormat = dataFormat;
    }   

    public async Task<VolumeDataset> ImportAsync()
    {
        VolumeDataset dataset = ScriptableObject.CreateInstance<VolumeDataset>();
        dataset.name = Path.GetFileNameWithoutExtension(filePath);
        dataset.width = width;
        dataset.height = height;
        dataset.depth = depth;

        // Open filestream and check size
        FileStream fs = new FileStream(filePath, FileMode.Open);
        BinaryReader reader = new BinaryReader(fs);

        long expectedFileSize = (long)(width * height * depth) * GetDataFormatSize(dataFormat);
        if (fs.Length < expectedFileSize)
        {
            Debug.LogError($"The dimension ({width}, {height}, {depth}) exceeds the file size. Expected file size is {expectedFileSize} bytes, while the actual file size is {fs.Length} bytes");
            reader.Close();
            fs.Close();
            return null;
        }

        // Read data async
        await Task.Run(() => {
            float[] data = new float[width * height * depth];

            float min = float.MaxValue;
            float max = float.MinValue;
            for (int i = 0; i < width * height * depth; i++)
            {
                float value = (float)ReadDataValue(reader);
                data[i] = value;
                if (value > max) max = value;
                if (value < min) min = value;
            }

            // Data
            ushort[] shorts = new ushort[width * height * depth];

            for(int i = 0; i < width * height * depth; i++)
            {
                // Convert to [0, 1] range
                float value = (data[i] - min) / (max - min);
                shorts[i] = Mathf.FloatToHalf(value);
            }
            reader.Close();
            fs.Close();

            dataset.SetData(shorts);
        });
        return dataset;
    }
    
    private int ReadDataValue(BinaryReader reader)
    {
        switch (dataFormat)
        {
            case DataFormat.UInt8:
            {
                return (int)reader.ReadByte();
            }
            case DataFormat.UInt16:
            {
                return (int)reader.ReadUInt16();
            }
        }
        throw new NotImplementedException("Invalid data format");
    }

    private int GetDataFormatSize(DataFormat format)
    {
        switch (format)
        {
            case DataFormat.UInt8:
                return 1;
            case DataFormat.UInt16:
                return 2;
        }
        throw new NotImplementedException("Invalid data format");
    }

}
