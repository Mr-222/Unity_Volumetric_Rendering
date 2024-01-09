using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CloudFeature : ScriptableRendererFeature
{
    [SerializeField]
    private CloudSettings settings;
    private Pass pass;
    
    private class Pass : ScriptableRenderPass
    {
        public string profilerTag;
        public CloudSettings settings;
        public RenderTexture tempTexture;
        
        public Pass(string profilerTag)
        {
            this.profilerTag = profilerTag;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            cameraTextureDescriptor.colorFormat = RenderTextureFormat.ARGB64;
            cameraTextureDescriptor.useMipMap = false;
            cameraTextureDescriptor.msaaSamples = 1;
            cameraTextureDescriptor.width /= (int)settings.downSampling;
            cameraTextureDescriptor.height /= (int)settings.downSampling;
            
            if (tempTexture == null || tempTexture.width != cameraTextureDescriptor.width
                                    || tempTexture.height != cameraTextureDescriptor.height)
            {
                if (tempTexture != null)
                {
                    tempTexture.Release();
                }

                tempTexture = RenderTexture.GetTemporary(cameraTextureDescriptor);
            }
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(profilerTag);
            
            settings.SetProperties();

            var cameraTarget = renderingData.cameraData.renderer.cameraColorTargetHandle.nameID;
            cmd.Blit(null, tempTexture, settings.material, 0);
            cmd.Blit(tempTexture, cameraTarget, settings.material, 1);
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public void Dispose()
        {
            tempTexture.Release();
        }
    }

    public override void Create()
    {
        pass = new Pass("Volumetric Clouds");
        name = "Volumetric Clouds";
        pass.settings = settings; 
        pass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }

    public void OnDisable()
    {
        pass.Dispose();
    }

    public void OnDestroy()
    {
        pass.Dispose();
    }
}
