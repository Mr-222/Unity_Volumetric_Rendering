Shader "Hidden/VolumetricLight"
{
    SubShader
    {
        Cull Off
        ZWrite Off
        Blend One One
        ZTest Always
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
        }
        
        HLSLINCLUDE
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Helpers.hlsl"
        
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        float _Scattering;
        float _Steps;
        float _MaxDistance;
        
        
        ENDHLSL
        
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _  _MAIN_LIGHT_SHADOWS_CASCADE 
            #pragma target 4.5

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

            float ComputeScattering(float LoV, float g)
            {
                real result = 1.0f - g * g;
                result /= 4.0f * PI * pow(1.0f + g * g - 2.0f * g * LoV, 1.5f);
                return result;
            }

            float4 frag(Varyings input) : SV_Target
            {
                float3 worldPos = GetWorldPosFromUV(input.uv);
                float3 startPosition = _WorldSpaceCameraPos;
                float3 rayVector = worldPos - startPosition;
                float3 rayDirection = normalize(rayVector);
                float rayLength = length(rayVector);
                rayLength = min(rayLength, _MaxDistance);
                Light mainLight = GetMainLight();
                float3 lightDirecrion = -normalize(mainLight.direction);

                
                float stepLength = rayLength / _Steps;
                float3 step = rayDirection * stepLength;
                float3 currentPosition = startPosition;
                // Offset the start position to avoid band artifact (convert to noise and we can blur in later stage)
                currentPosition += step * InterleavedGradientNoise(input.uv, 0);

                float3 accumFog = 0;
                for (int i=0; i<_Steps-1; ++i)
                {
                    float shadowMapValue = ShadowAtten(currentPosition);
                    // Visibility term is 1, it is in light
                    if (shadowMapValue > 0)
                    {
                        float kernelColor = ComputeScattering(dot(rayDirection, lightDirecrion), _Scattering);
                        accumFog += kernelColor.xxx * mainLight.color;
                    }
                    currentPosition += step;
                }
                accumFog /= _Steps;
                
                return float4(accumFog , 1.0);
            }
            
            ENDHLSL
        }
    }
}
