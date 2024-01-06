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
        
        public Pass(string profilerTag)
        {
            this.profilerTag = profilerTag;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(profilerTag);
            
            settings.SetProperties();

            var cameraTarget = renderingData.cameraData.renderer.cameraColorTargetHandle.nameID;
            cmd.Blit(null, cameraTarget, settings.material);
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
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
}
