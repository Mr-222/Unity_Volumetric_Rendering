Shader "Hidden/VolumetricLight"
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
            Name "Volumetric Scattering"
            
            Cull Off
            ZWrite Off
            ZTest Always
            Blend One Zero
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ADDITIONAL_LIGHT_SHADOWS
            #pragma target 4.5
            
            #pragma  multi_compile _ _SCHLICK _HENYEY_GREENSTEIN

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Helpers.hlsl"
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float _Scattering;
            float _SigmaS;
            float _SigmaT;
            float _Intensity;
            float _Steps;
            float _MaxDistance;
            float _Jitter;
            int _AddtionalLightsCount;

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
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                
                return output;
            }

            float HenyeyGreenStein(float LoV, float g)
            {
                float result = 1.0f - g * g;
                result /= 4.0f * PI * pow(1.0f + g * g - 2.0f * g * LoV, 1.5f);
                return result;
            }

            float Schlick(float LoV, float k)
            {
                return (1.0f - k * k) / (4.0 * PI * pow(1.0f + k * LoV, 2.0f));
            }

            float phaseFunction(float LoV, float g)
            {
                #if defined(_HENYEY_GREENSTEIN)
                    return HenyeyGreenStein(LoV, g);
                #elif defined(_SCHLICK)
                    float k = 1.55f * g - 0.55f * g * g * g;
                    return Schlick(LoV, k);
                #endif
                    return HenyeyGreenStein(LoV, g);
            }

            float4 frag(Varyings input) : SV_Target
            {
                float3 worldPos = GetWorldPosFromUV(input.uv);
                float3 startPosition = _WorldSpaceCameraPos;
                float3 rayVector = worldPos - startPosition;
                float3 rayDirection = normalize(rayVector);
                float rayLength = length(rayVector);
                rayLength = min(rayLength, _MaxDistance);

                // Main light
                Light mainLight = GetMainLight();
                float3 lightDirecrion = -normalize(mainLight.direction);
                
                float stepLength = rayLength / _Steps;
                float3 step = rayDirection * stepLength;
                
                // Offset the start position to avoid band artifact (convert to noise and we can blur in later stage)
                float rayStartOffset = rand(input.uv) * stepLength;
              
                float3 currentPosition = startPosition + rayDirection * rayStartOffset * _Jitter;

                float3 accumFog = 0;
                float transmittance = 1.0;
                for (int i=0; i<_Steps; ++i)
                {
                    // See slide 28 at http://www.frostbite.com/2015/08/physically-based-unified-volumetric-rendering-in-frostbite/
                    float3 S = mainLight.color * _Intensity * _SigmaS *
                        phaseFunction(dot(rayDirection, lightDirecrion), _Scattering) * MainLightShadowAtten(currentPosition);
                    float3 Sint = (S - S * exp(-_SigmaT * stepLength)) / _SigmaT;
                    accumFog += transmittance * Sint;
                    transmittance *= exp(-_SigmaT * stepLength);
                    currentPosition += step;
                }

                // Additional lights
                for (int j=0; j<_AddtionalLightsCount; ++j)
                {
                    rayVector = worldPos - startPosition;
                    rayDirection = normalize(rayVector);
                    rayLength = length(rayVector);
                    stepLength = rayLength / _Steps;
                    step = rayDirection * stepLength;
                    rayStartOffset = rand(input.uv) * stepLength;
                    currentPosition = startPosition + rayDirection * rayStartOffset * _Jitter;
                    Light light = GetAdditionalLight(j, currentPosition, 1.0);
                
                    transmittance = 1.0;
                    for (int i=0; i<_Steps; ++i)
                    {
                        float3 S = light.color * _Intensity * _SigmaS * light.distanceAttenuation * light.shadowAttenuation *
                            phaseFunction(dot(rayDirection, light.direction), _Scattering) * 1.0;
                        float3 Sint = (S - S * exp(-_SigmaT * stepLength)) / _SigmaT;
                        accumFog += transmittance * Sint;
                        transmittance *= exp(-_SigmaT * stepLength);
                        currentPosition += step;
                        light = GetAdditionalLight(j, currentPosition, 1.0);
                    }
                }
                
                return float4(accumFog , 1.0);
            }
            
            ENDHLSL
        }
        
        UsePass "Hidden/Gaussian_Blur_X/GAUSSIAN_BLUR_X"
        
        UsePass "Hidden/Gaussian_Blur_Y/GAUSSIAN_BLUR_Y"
        
        UsePass "Hidden/DownSampleDepth/DOWNSAMPLEDEPTH"
        
        UsePass "Hidden/UpSamplingAndBlend/UpSamplingAndBlend"
    }
}
