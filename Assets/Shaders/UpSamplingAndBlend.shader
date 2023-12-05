Shader "Hidden/UpSamplingAndBlend"
{
    SubShader
    {
        Pass
        {
            Name "UpSamplingAndBlend"
            
            Cull Off 
            ZWrite Off 
            ZTest Always
            Blend One One

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #pragma vertex vert
            #pragma fragment frag
            
            TEXTURE2D(_LowResDepth);
            SAMPLER(sampler_LowResDepth);
            TEXTURE2D(_VolumetricTexture);
            SAMPLER(sampler_VolumetricTexture);

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
                float3 col = 0;

                // Depth at high res fragment
                float d0 = SampleSceneDepth(input.uv);

                // Calculate distance between pixels
                float d1 = _LowResDepth.Sample(sampler_LowResDepth, input.uv, int2(0, 1)).r;
                float d2 = _LowResDepth.Sample(sampler_LowResDepth, input.uv, int2(0, -1)).r;
                float d3 = _LowResDepth.Sample(sampler_LowResDepth, input.uv, int2(1, 0)).r;
                float d4 = _LowResDepth.Sample(sampler_LowResDepth, input.uv, int2(-1, 0)).r;

                d1 = abs(d0 - d1);
                d2 = abs(d0 - d2);
                d3 = abs(d0 - d3);
                d4 = abs(d0 - d4);
                float dmin = min(min(d1, d2), min(d3, d4));

                int offset = 0;
                if (dmin == d1) offset = 1;
                else if (dmin == d2) offset = 2;
                else if (dmin == d3) offset = 3;
                else if (dmin == d4) offset = 4;

                switch (offset)
                {
                case 1:
                    col = _VolumetricTexture.Sample(sampler_VolumetricTexture, input.uv, int2(0, 1)).rgb;
                    break;
                case 2:
                    col = _VolumetricTexture.Sample(sampler_VolumetricTexture, input.uv, int2(0, -1)).rgb;
                    break;
                case 3:
                    col = _VolumetricTexture.Sample(sampler_VolumetricTexture, input.uv, int2(1, 0)).rgb;
                    break;
                case 4:
                    col = _VolumetricTexture.Sample(sampler_VolumetricTexture, input.uv, int2(-1, 0)).rgb;
                    break;
                default:
                    col = _VolumetricTexture.Sample(sampler_VolumetricTexture, input.uv).rgb;
                    break;
                }
                
                return float4(col, 1.0);
            }
            
            ENDHLSL
        }
    }
}
