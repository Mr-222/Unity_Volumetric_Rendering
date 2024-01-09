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
            Name "Draw Cloud"
            
            Cull Off ZWrite Off ZTest Always
            Blend One Zero
            
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Helpers.hlsl"

            float3 _CloudBoundsMin;
            float3 _CloudBoundsMax;

            // Raymarch
            TEXTURE2D(_BlueNoise);
            SAMPLER(sampler_BlueNoise);
            float _RayStep;
            float _RayOffsetStrength;
            
            // Lighting
            float _G1;
            float _G2;
            float _Alpha;
            float _SunIntensity;
            float _LightAbsorptionThroughCloud;
            float _LightAbsorptionTowardSun;
            float _PowderEffectScale;
            float3 _DarknessThreshold;
            float3 _ColA;
            float3 _ColB;
            float _ColorScaleA;
            float _ColorScaleB;

            // Shape
            TEXTURE2D(_WeatherMap);
            SAMPLER(sampler_WeatherMap);
            TEXTURE3D(_NoiseBase);
            SAMPLER(sampler_NoiseBase);
            TEXTURE3D(_NoiseDetail);
            SAMPLER(sampler_NoiseDetail);
            float _ShapeTiling;
            float _DetailTiling;
            float _ShapeSpeed;
            float _DetailSpeed;
            float _DetailWeight;
            float _HeightOffset;
            float4 _ShapeNoiseWeights;
            float _DensityOffset;
            float _DensityMultiplier;
            
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _POWDER_EFFECT

            #include "CloudsPass.hlsl"

            ENDHLSL
        }

        Pass 
        {
            Name "Blend"
            
            Cull Off ZWrite Off ZTest Always
            Blend One SrcAlpha
            
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_MainTex);
            SAMPLER(my_trilinear_clamp_sampler);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS);
                output.uv = input.uv;

                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                float4 cloud = SAMPLE_TEXTURE2D_LOD(_MainTex, my_trilinear_clamp_sampler, input.uv, 0);

                return cloud;
            }
            
            ENDHLSL
        }
    }
}
