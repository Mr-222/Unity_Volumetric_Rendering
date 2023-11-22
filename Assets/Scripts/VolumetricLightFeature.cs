using System;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class VolumetricLightFeature : ScriptableRendererFeature
{
    [Serializable]
    public class Settings
    {
        public Material material;
        
        [Range(-1 ,1)]
        public float scattering = 0.4f;

        [Range(10, 100)]
        public int steps = 25;

        [Range(10, 300)]
        public int maxDistance = 75;
        
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public Settings settings = new Settings();

    class Pass : ScriptableRenderPass
    {
        public Settings settings;
        private RTHandle source;
        private RTHandle tempTexture;

        private string profilerTag;
        
        public Pass(string profilerTag)
        {
            this.profilerTag = profilerTag;
        }
        
        public void SetUp(RTHandle source)
        {
            this.source = source;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            base.Configure(cmd, cameraTextureDescriptor);
            cameraTextureDescriptor.colorFormat = RenderTextureFormat.R16;
            cameraTextureDescriptor.msaaSamples = 1;

            if (tempTexture == null || tempTexture.rt.width != cameraTextureDescriptor.width 
                                    || tempTexture.rt.height != cameraTextureDescriptor.height)
            {
                if (tempTexture != null)
                    tempTexture.Release();
                tempTexture = RTHandles.Alloc(cameraTextureDescriptor);
            }
            ConfigureTarget(tempTexture);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);

            try
            { 
                settings.material.SetFloat("_Scattering", settings.scattering);
                settings.material.SetFloat("_Steps", settings.steps);
                settings.material.SetFloat("_MaxDistance", settings.maxDistance);
                
                cmd.Blit(source, tempTexture);
                cmd.Blit(tempTexture, source, settings.material, 0);
                
                context.ExecuteCommandBuffer(cmd);
            }
            catch
            {
                Debug.LogError("VolumetricLightFeature: Something went wrong with the blit");
            }
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
    }
    
    Pass pass;

    public override void Create()
    {
        pass = new Pass("Volumetric Light");
        name = "Volumetric Light";
        pass.settings = settings;
        pass.renderPassEvent = settings.renderPassEvent;
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        base.SetupRenderPasses(renderer, in renderingData);
        pass.SetUp(renderer.cameraColorTargetHandle);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}
