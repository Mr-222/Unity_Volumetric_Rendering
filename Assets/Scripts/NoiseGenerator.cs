using System;
using Unity.Collections;
using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using Random = UnityEngine.Random;

[ExecuteAlways]
public class NoiseGenerator : MonoBehaviour
{
    public int texResolution = 256;
    public int cellResolution = 4;
    public bool invert = false;
    public string fileName = "WorleyNoise2D";
    public ComputeShader shader;
    
    private ComputeBuffer buffer;

    public void Generate2D()
    {
        int kernelHandle = shader.FindKernel("CSWorley2D");
        ComputeBuffer buffer = CreateWorleyPointsBuffer2D(cellResolution, "_FeaturePoints2D", kernelHandle);
        RenderTexture noiseTex = Dispatch2D(kernelHandle);
        saveToPNG(noiseTex, fileName);
        buffer.Release();
    }

    public void Generate3D()
    {
        int kernelHandle = shader.FindKernel("CSWorley3D");
        ComputeBuffer buffer = CreateWorleyPointsBuffer3D(cellResolution, "_FeaturePoints3D", kernelHandle);
        RenderTexture noiseTex = Dispatch3D(kernelHandle);
        SaveRT3DToTexture3DAsset(noiseTex, fileName);
        buffer.Release();
    }

    ComputeBuffer CreateWorleyPointsBuffer2D(int numCellsPerAxis, string bufferName, int kernel)
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

    ComputeBuffer CreateWorleyPointsBuffer3D(int numCellsPerAxis, string bufferName, int kernel)
    {
        var points = new Vector3[numCellsPerAxis * numCellsPerAxis * numCellsPerAxis];
        for (int x = 0; x < numCellsPerAxis; x++)
        {
            for (int y = 0; y < numCellsPerAxis; y++)
            {
                for (int z = 0; z < numCellsPerAxis; z++)
                {
                    var position = new Vector3(Random.Range(-0.5f, 0.5f), Random.Range(-0.5f, 0.5f), Random.Range(-0.5f, 0.5f));
                    int index = x + numCellsPerAxis * y + numCellsPerAxis * numCellsPerAxis * z;
                    points[index] = position;
                }
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

    RenderTexture Dispatch2D(int kernel)
    {
        if (invert)
            shader.EnableKeyword("_Invert");
        else
            shader.DisableKeyword("_Invert");
        shader.SetInt("_Resolution", texResolution);
        shader.SetInt("_CellResolution", cellResolution);
        
        RenderTexture noise = RenderTexture.GetTemporary(texResolution, texResolution, 0, RenderTextureFormat.Default);
        noise.enableRandomWrite = true;
        noise.wrapMode = TextureWrapMode.Repeat;
        noise.Create();
        shader.SetTexture(kernel, "_NoiseTex2D", noise);
        
        shader.Dispatch(kernel, texResolution / 8, texResolution / 8, 1);

        GetComponent<Renderer>().sharedMaterial.mainTexture = noise;

        return noise;
    }
    
    RenderTexture Dispatch3D(int kernel)
    {
        if (invert)
            shader.EnableKeyword("_Invert");
        else
            shader.DisableKeyword("_Invert");
        shader.SetInt("_Resolution", texResolution);
        shader.SetInt("_CellResolution", cellResolution);
        
        RenderTexture noise = new RenderTexture(texResolution, texResolution, 0, RenderTextureFormat.R8)
        {
            enableRandomWrite = true,
            dimension = TextureDimension.Tex3D,
            volumeDepth = texResolution,
            wrapMode = TextureWrapMode.Repeat,
            filterMode = FilterMode.Bilinear
        };
        noise.Create();
        shader.SetTexture(kernel, "_NoiseTex3D", noise);
        
        shader.Dispatch(kernel, texResolution / 8, texResolution / 8, texResolution / 8);

        GetComponent<Renderer>().sharedMaterial.mainTexture = noise;

        return noise;
    }

    public void saveToPNG(RenderTexture rt, string pathWithoutAssetsAndExtension)
    {
        int resolutionX = rt.width;
        int resolutionY = rt.height;
        
        var tex = new Texture2D(resolutionX, resolutionY, TextureFormat.RGBA32, false);
        RenderTexture.active = rt;
        tex.ReadPixels(new Rect(0, 0, resolutionX, resolutionY), 0, 0);
        tex.Apply();
        byte[] bytes = tex.EncodeToPNG();
        System.IO.File.WriteAllBytes(Application.dataPath + "/Textures/" + pathWithoutAssetsAndExtension + ".png", bytes);
    }
    
    // https://forum.unity.com/threads/rendertexture-3d-to-texture3d.928362/
    void SaveRT3DToTexture3DAsset(RenderTexture rt3D, string pathWithoutAssetsAndExtension)
    {
        int width = rt3D.width, height = rt3D.height, depth = rt3D.volumeDepth;
        // Change if format is not 8 bits (i was using R8_UNorm) (create a struct with 4 bytes etc)
        var a = new NativeArray<byte>(width * height * depth, Allocator.Persistent, NativeArrayOptions.UninitializedMemory);
        AsyncGPUReadback.RequestIntoNativeArray(ref a, rt3D, 0, (_) =>
        {
            Texture3D output = new Texture3D(width, height, depth, rt3D.graphicsFormat, TextureCreationFlags.None);
            output.SetPixelData(a, 0);
            output.Apply(updateMipmaps: false, makeNoLongerReadable: true);
            AssetDatabase.CreateAsset(output, $"Assets/Textures/{pathWithoutAssetsAndExtension}.asset");
            AssetDatabase.SaveAssetIfDirty(output);
            a.Dispose();
            //rt3D.Release();
        });
    }
}
