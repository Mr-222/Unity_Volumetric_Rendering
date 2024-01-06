Shader "Hidden/Gaussian_Blur_X"
{
     SubShader
     {
        Blend One Zero

        Pass
        {
            Name "Gaussian_Blur_X"
            
            Cull Off
            ZWrite Off
            ZTest Always
            Blend One Zero
            
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Macros.hlsl"

            #pragma vertex vert
            #pragma fragment frag

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
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_TexelSize;
            int _GaussSamples;
            float _GaussAmount;
            static const float gauss_filter_weights[] =
                { 0.14446445, 0.13543542, 0.11153505, 0.08055309, 0.05087564, 0.02798160, 0.01332457, 0.00545096 };

            float4 frag(Varyings input) : SV_Target
            {
                float accumWeight = 0.f;
                float3 accumResult = 0.f;
                
                float centerDepth = DEPTH_01(input.uv);
                for (int index=-_GaussSamples; index<=_GaussSamples; ++index)
                {
                    float2 uv = input.uv + float2(index * _MainTex_TexelSize.x * _GaussAmount, 0.f);
                    
                    float3 sample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;
                    // Weight based on depth difference 
                    float depth = DEPTH_01(uv);
                    float depthDiff = abs(centerDepth - depth);
                    float r2 = depthDiff * BLUR_DEPTH_FALLOFF;
                    float g = exp(-r2 * r2);
                    float weight = g * gauss_filter_weights[abs(index)];
                    accumResult += weight * sample;
                    accumWeight += weight;
                }

                accumResult = accumResult / accumWeight;
                return float4(accumResult, 1.0);
            }
            
            ENDHLSL
        }
    }
}
