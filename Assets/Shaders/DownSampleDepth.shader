Shader "Hidden/DownSampleDepth"
{
    SubShader
    {
        Blend One Zero

        Pass
        {
            Name "DownSampleDepth"
            
            Cull Off
            ZWrite Off
            Blend One Zero
            ZTest Always

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

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

            float frag(Varyings input) : SV_Target
            {
                return SampleSceneDepth(input.uv);
            }
            
            ENDHLSL
        }
    }
}
