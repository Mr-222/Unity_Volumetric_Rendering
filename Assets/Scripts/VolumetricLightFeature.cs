using System;
using System.Linq;
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

        [Range(0.01f, 3f)]
        public float sigmaS = 0.5f;

        [Range(0.01f, 3f)] 
        public float sigmaT = 0.7f;
        
        [Range(0.2f, 10.0f)]
        public float intensity = 5;

        [Range(5, 100)]
        public int steps = 10;

        [Range(5, 300)]
        public int maxDistance = 75;

        [Range(0.5f, 3f)] 
        public float jitter = 2.5f;
        
        public enum DownSample
        {
            off = 1,
            half = 2,
            quarter = 4
        }
        public DownSample downsampling = DownSample.off;

        public enum UpSample
        {
            normal = 1,
            depthAware = 2
        }
        public UpSample upsampling = UpSample.normal;

        public enum PhaseFunction
        {
            HenyeyGreenstein,
            Schlick
        }
        public PhaseFunction phaseFunction = PhaseFunction.HenyeyGreenstein;

        [Serializable]
        public class GaussianBlur
        {
            [Range(1, 10)]
            public float amount;
            
            [Range(3, 7)]
            public int samples;
        }
        public GaussianBlur gaussianBlur = new GaussianBlur { amount = 2.5f, samples = 7 };
        
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public Settings settings = new Settings();
    
    

    class Pass : ScriptableRenderPass
    {
        public Settings settings;
        private RenderTexture tempTexture1;
        private RenderTexture tempTexture2;

        private string profilerTag;
        
        public Pass(string profilerTag)
        {
            this.profilerTag = profilerTag;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            base.Configure(cmd, cameraTextureDescriptor);
            
            var originalDescriptor = cameraTextureDescriptor;
            
            cameraTextureDescriptor.colorFormat = RenderTextureFormat.ARGB64;
            cameraTextureDescriptor.msaaSamples = 1;
            cameraTextureDescriptor.width /= (int)settings.downsampling;
            cameraTextureDescriptor.height /= (int)settings.downsampling;

            if (tempTexture1 == null || tempTexture1.width != cameraTextureDescriptor.width
                                     || tempTexture1.height != cameraTextureDescriptor.height)
            {
                if (tempTexture1 != null)
                {
                    tempTexture1.Release();
                }
                if (tempTexture2 != null)
                {
                    tempTexture2.Release();
                }
                
                tempTexture1 = RenderTexture.GetTemporary(cameraTextureDescriptor); 
                tempTexture2 = RenderTexture.GetTemporary(cameraTextureDescriptor);
            }
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
            
            settings.material.SetFloat("_Scattering", settings.scattering);
            settings.material.SetFloat("_SigmaS", settings.sigmaS);
            settings.material.SetFloat("_SigmaT", settings.sigmaT);
            settings.material.SetFloat("_Intensity", settings.intensity);
            settings.material.SetFloat("_Steps", settings.steps);
            settings.material.SetFloat("_MaxDistance", settings.maxDistance);
            settings.material.SetFloat("_Jitter", settings.jitter);
            settings.material.SetFloat("_GaussAmount", settings.gaussianBlur.amount);
            settings.material.SetInt("_GaussSamples", settings.gaussianBlur.samples);
            if (settings.phaseFunction == Settings.PhaseFunction.HenyeyGreenstein)
            {
                settings.material.EnableKeyword("_HENYEY_GREENSTEIN");
                settings.material.DisableKeyword("_SCHLICK");
            }
            else
            {
                settings.material.EnableKeyword("_SCHLICK");
                settings.material.DisableKeyword("_HENYEY_GREENSTEIN");
            }
            
            Light[] lights = FindObjectsOfType<Light>();
            int addtionalLights = lights.Count(light => light.type != LightType.Directional);
            settings.material.SetInt("_AdditionalLightsNum", addtionalLights);

            var cameraTarget = renderingData.cameraData.renderer.cameraColorTargetHandle.nameID;
            // Raymarch
            cmd.Blit(cameraTarget, tempTexture1, settings.material, 0);
            // Gaussian Blur X
            cmd.Blit(tempTexture1, tempTexture2, settings.material, 1);
            
            if (settings.upsampling == Settings.UpSample.normal)
            {
                settings.material.SetInt("_BlendSrc", (int)BlendMode.One);
                settings.material.SetInt("_BlendDst", (int)BlendMode.One);
                // Gaussian Blur Y
                cmd.Blit(tempTexture2, cameraTarget, settings.material, 2);
            }
            else
            {
                settings.material.SetInt("_BlendSrc", (int)BlendMode.One);
                settings.material.SetInt("_BlendDst", (int)BlendMode.Zero);
                // Gaussian Blur Y
                cmd.Blit(tempTexture2, tempTexture1, settings.material, 2);
                // Downsample Depth, use tempTexture2 as low res depth buffer
                cmd.Blit(cameraTarget, tempTexture2, settings.material, 3);
                // Upsampling and Additive Blending
                cmd.SetGlobalTexture("_LowResDepth", tempTexture2);
                cmd.SetGlobalTexture("_VolumetricTexture", tempTexture1);
                cmd.Blit(tempTexture1, cameraTarget, settings.material, 4);
            }
            
            context.ExecuteCommandBuffer(cmd);
            
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
        
        public void Dispose()
        {
            if (tempTexture1 != null)
            {
                tempTexture1.Release();
            }
            if (tempTexture2 != null)
            {
                tempTexture2.Release();
            }
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
    
    public void OnValidate()
    {
        if (settings.sigmaT < settings.sigmaS)
        {
            settings.sigmaT = settings.sigmaS;
        }
    }
}
