Shader "Custom/Clouds"
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
            float _Step;
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

            // Henyey-Greenstein
            float hg(float a, float g) {
                float g2 = g * g;
                return (1 - g2) / (4 * 3.1415 * pow(1 + g2 - 2 * g * (a), 1.5));
            }

            float phase(float a) {
                float blend = .5;
                float hgBlend = hg(a, _PhaseParams.x) * (1 - blend) + hg(a, -_PhaseParams.y) * blend;
                return _PhaseParams.z + hgBlend * _PhaseParams.w;
            }

            // float phase(float a) {
            //     float blend = .5;
            //     float hgBlend = HenyeyGreenStein(a, _PhaseParams.x) * (1 - blend) + HenyeyGreenStein(a, -_PhaseParams.y) * blend;
            //     return _PhaseParams.z + hgBlend * _PhaseParams.w;
            // }

            float sampleDensity(float3 rayPos) 
            {
                float4 boundsCentre = (_CloudBoundsMin + _CloudBoundsMax) * 0.5;
                float3 size = _CloudBoundsMax.xyz - _CloudBoundsMin.xyz;
                const float4 _xy_Speed_zw_Warp = float4(0.05, 0.3, 0, 0);
                float speedShape = _Time.y * _xy_Speed_zw_Warp.x;
                float speedDetail = _Time.y * _xy_Speed_zw_Warp.y;

                float3 uvwShape  = rayPos * _ShapeTiling + float3(speedShape, speedShape * 0.2,0);
                float3 uvwDetail = rayPos * _DetailTiling + float3(speedDetail, speedDetail * 0.2,0);

                float2 uv = (size.xz * 0.5f + (rayPos.xz - boundsCentre.xz) ) / float2(size.x,size.z);
     
                //float4 maskNoise = SAMPLE_TEXTURE2D(_MaskNoise, float4(uv + float2(speedShape * 0.5, 0), 0, 0));
                float4 weatherMap = SAMPLE_TEXTURE2D_LOD(_WeatherMap, sampler_WeatherMap, uv+float2(speedShape*0.5, 0), 0);

                float4 shapeNoise = SAMPLE_TEXTURE3D_LOD(_NoiseBase, sampler_NoiseBase, uvwShape, 0);
                float4 detailNoise = SAMPLE_TEXTURE3D_LOD(_NoiseDetail, sampler_NoiseDetail, uvwDetail, 0);

                //边缘衰减
                const float containerEdgeFadeDst = 10;
                float dstFromEdgeX = min(containerEdgeFadeDst, min(rayPos.x - _CloudBoundsMin.x, _CloudBoundsMax.x - rayPos.x));
                float dstFromEdgeZ = min(containerEdgeFadeDst, min(rayPos.z - _CloudBoundsMin.z, _CloudBoundsMax.z - rayPos.z));
                float edgeWeight = min(dstFromEdgeZ, dstFromEdgeX) / containerEdgeFadeDst;

                float gMin = Remap(weatherMap.x, 0, 1, 0.1, 0.6);
                float gMax = Remap(weatherMap.x, 0, 1, gMin, 0.9);
                float heightPercent = (rayPos.y - _CloudBoundsMin.y) / size.y;
                float heightGradient = saturate(Remap(heightPercent, 0.0, gMin, 0, 1)) *
                    saturate(Remap(heightPercent, 1, gMax, 0, 1));
                float heightGradient2 = saturate(Remap(heightPercent, 0.0, weatherMap.r, 1, 0)) *
                    saturate(Remap(heightPercent, 0.0, gMin, 0, 1));
                heightGradient = saturate(lerp(heightGradient, heightGradient2, _HeightWeights));

                heightGradient *= edgeWeight;

                float4 normalizedShapeWeights = _ShapeNoiseWeights / dot(_ShapeNoiseWeights, 1);
                float shapeFBM = dot(shapeNoise, normalizedShapeWeights) * heightGradient;
                float baseShapeDensity = shapeFBM + _DensityOffset * 0.01;
                
                if (baseShapeDensity > 0)
                {
                    float detailFBM = detailNoise.r;
                    float oneMinusShape = 1 - baseShapeDensity;
                    
                    float cloudDensity = baseShapeDensity - detailFBM  * _DetailWeights * oneMinusShape * oneMinusShape * oneMinusShape;
   
                    return saturate(cloudDensity * _DensityMultiplier);
                }
                return 0;
            }

            float3 lightmarch(float3 position ,float dstTravelled)
            {
                float3 dirToLight = normalize(_MainLightPosition).xyz;

                //灯光方向与边界框求交，超出部分不计算
                float dstInsideBox = rayBoxDst(_CloudBoundsMin, _CloudBoundsMax, position, dirToLight).y;
                float stepSize = dstInsideBox / 8;
                float totalDensity = 0;

                for (int step = 0; step < 8; step++) { //灯光步进次数
                    position += dirToLight * stepSize; //向灯光步进
                    //totalDensity += max(0, sampleDensity(position) * stepSize);                     totalDensity += max(0, sampleDensity(position) * stepSize);
                    totalDensity += max(0, sampleDensity(position));

                }
                float transmittance = exp(-totalDensity * _LightAbsorptionTowardSun);

                //将重亮到暗映射为 3段颜色 ,亮->灯光颜色 中->ColorA 暗->ColorB
                float3 cloudColor = lerp(_ColA, _MainLightColor, saturate(transmittance * _ColorScaleA));
                cloudColor = lerp(_ColB, cloudColor, saturate(pow(transmittance * _ColorScaleB, 3)));
                return _DarknessThreshold + transmittance * (1 - _DarknessThreshold) * cloudColor;
            }
            
            float4 frag(Varyings input) : SV_Target
            {
                float3 worldPos = GetWorldPosFromUV(input.uv);
                float3 rayPos = _WorldSpaceCameraPos;
                float3 worldViewDir = normalize(worldPos - rayPos.xyz);
                float depthEyeLinear = length(worldPos.xyz - rayPos.xyz);

                float2 rayToContainerInfo = rayBoxDst(_CloudBoundsMin, _CloudBoundsMax, rayPos, worldViewDir);
                float dstToBox = rayToContainerInfo.x;
                float dstInsideBox = rayToContainerInfo.y;

                float3 entryPoint = rayPos + worldViewDir * dstToBox;
                float dstLimit = min(depthEyeLinear - dstToBox, dstInsideBox);

                // Jitter sample point to avoid banding
                float blueNoise = SAMPLE_TEXTURE2D(_BlueNoise, sampler_BlueNoise, input.uv).r;
                
                float cosAngle = dot(-worldViewDir, normalize(_MainLightPosition.xyz));
                float3 phaseVal = phase(cosAngle);

                float dstTravelled = blueNoise.r * _RayOffsetStrength;
                float sumDensity = 1.0;
                float3 lightEnergy = 0;
                const float sizeLoop = 512;
                float stepSize = exp(_Step) * _RayStep;

                for (int j=0; j<sizeLoop; ++j)
                {
                    if (dstTravelled < dstLimit)
                    {
                        rayPos = entryPoint + worldViewDir * dstTravelled;
                        float density = sampleDensity(rayPos);
                        if (density > 0)
                        {
                            float3 lightTransmittance = lightmarch(rayPos, dstTravelled);
                            lightEnergy += density * stepSize * sumDensity * lightTransmittance * phaseVal;
                            sumDensity *= exp(-density * stepSize * _LightAbsorptionThroughCloud);

                        }
                    }
                    dstTravelled += stepSize;
                }

                return float4(lightEnergy, sumDensity);
            }

            ENDHLSL
        }
    }
}
