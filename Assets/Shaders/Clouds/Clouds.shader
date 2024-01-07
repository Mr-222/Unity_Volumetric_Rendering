Shader "Custom/Cloud"
{
    Properties
    {
        // If you provide a mat material that doesn't have a _MainTex property, Blit doesn't use source.
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
        }

        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Blend One SrcAlpha
            
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Helpers.hlsl"

            float4 _CloudBoundsMin;
            float4 _CloudBoundsMax;
            float4 _PhaseParams;
            float _RayOffsetStrength;
            float _RayStep;
            float _LightAbsorptionThroughCloud;
            float _LightAbsorptionTowardSun;
            float3 _DarknessThreshold;
            float3 _ColA;
            float3 _ColB;
            float _ColorScaleA;
            float _ColorScaleB;
            float3 _ShapeTiling;
            float3 _DetailTiling;
            float _ShapeSpeed;
            float _DetailSpeed;
            float _HeightWeights;
            float4 _ShapeNoiseWeights;
            float _DensityOffset;
            float _DetailWeights;
            float _DensityMultiplier;
            
            TEXTURE2D(_BlueNoise);
            SAMPLER(sampler_BlueNoise);
            TEXTURE2D(_MaskNoise);
            SAMPLER(sampler_MaskNoise);
            TEXTURE2D(_WeatherMap);
            SAMPLER(sampler_WeatherMap);
            TEXTURE3D(_NoiseBase);
            SAMPLER(sampler_NoiseBase);
            TEXTURE3D(_NoiseDetail);
            SAMPLER(sampler_NoiseDetail);
            
            #pragma vertex vert
            #pragma fragment frag

            #include "CloudsPass.hlsl"

            ENDHLSL
        }
    }
}
