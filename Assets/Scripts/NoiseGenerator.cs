using System;
using UnityEngine;
using Random = UnityEngine.Random;

[ExecuteAlways]
public class NoiseGenerator : MonoBehaviour
{
    public int texResolution = 256;
    public int cellResolution = 4;
    public bool invert = false;
    public string savedName = "WorleyNoise2D";
    public ComputeShader shader;
    
    private ComputeBuffer buffer;

    public void Generate()
    {
        int kernelHandle = shader.FindKernel("CSWorley2D");
        ComputeBuffer buffer = CreateWorleyPointsBuffer(cellResolution, "_FeaturePoints", kernelHandle);
        RenderTexture noiseTex = Dispatch(kernelHandle);
        saveToPNG(noiseTex);
        buffer.Release();
    }

    ComputeBuffer CreateWorleyPointsBuffer(int numCellsPerAxis, string bufferName, int kernel)
    {
        var points = new Vector3[numCellsPerAxis * numCellsPerAxis];
        for (int x = 0; x < numCellsPerAxis; x++)
        {
            for (int y = 0; y < numCellsPerAxis; y++)
            {
                    var position = new Vector3(Random.Range(-0.5f, 0.5f), Random.Range(-0.5f, 0.5f));
                    int index = x + numCellsPerAxis * y;
                    points[index] = position;
            }
        }
        
        return CreateBuffer(points, 3 * sizeof(float), bufferName, kernel);
    }

    ComputeBuffer CreateBuffer(Array data, int stride, string bufferName, int kernel)
    {
        buffer = new ComputeBuffer(data.Length, stride, ComputeBufferType.Raw);
        buffer.SetData(data);
        shader.SetBuffer(kernel, bufferName, buffer);

        return buffer;
    }

    RenderTexture Dispatch(int kernel)
    {
        if (invert)
            shader.EnableKeyword("_Invert");
        else
            shader.DisableKeyword("_Invert");
        shader.SetInt("_Resolution", texResolution);
        shader.SetInt("_CellResolution", cellResolution);
        
        RenderTexture noise = RenderTexture.GetTemporary(texResolution, texResolution, 0, RenderTextureFormat.Default);
        noise.enableRandomWrite = true;
        noise.Create();
        shader.SetTexture(kernel, "_NoiseTex", noise);
        
        shader.Dispatch(kernel, texResolution / 8, texResolution / 8, 1);

        GetComponent<Renderer>().material.mainTexture = noise;

        return noise;
    }

    public void saveToPNG(RenderTexture rt)
    {
        int resolutionX = rt.width;
        int resolutionY = rt.height;
        
        var tex = new Texture2D(resolutionX, resolutionY, TextureFormat.RGBA32, false);
        RenderTexture.active = rt;
        tex.ReadPixels(new Rect(0, 0, resolutionX, resolutionY), 0, 0);
        tex.Apply();
        byte[] bytes = tex.EncodeToPNG();
        System.IO.File.WriteAllBytes(Application.dataPath + "/Textures/" + savedName + ".png", bytes);
    }
}
