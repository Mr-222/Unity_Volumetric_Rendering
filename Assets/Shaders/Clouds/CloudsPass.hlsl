#ifndef CUSTOM_CLOUDS_PASS
#define CUSTOM_CLOUDS_PASS

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

float sampleDensity(float3 rayPos) 
{
    float4 boundsCentre = (_CloudBoundsMin + _CloudBoundsMax) * 0.5;
    float3 size = _CloudBoundsMax.xyz - _CloudBoundsMin.xyz;

    float speedShape = _ShapeSpeed * _Time.y;
    float speedDetail = _DetailSpeed * _Time.y;
    float3 uvwShape  = rayPos * _ShapeTiling + float3(speedShape * 0.2, speedShape * 0.1,0);
    float3 uvwDetail = rayPos * _DetailTiling + float3(speedDetail * 0.2, speedDetail * 0.1,0);
    float2 uv = (size.xz * 0.5f + (rayPos.xz - boundsCentre.xz) ) / float2(size.x,size.z);
                
    float4 weatherMap = SAMPLE_TEXTURE2D_LOD(_WeatherMap, sampler_WeatherMap, uv+float2(speedShape*0.2, 0), 0);
    float4 shapeNoise = SAMPLE_TEXTURE3D_LOD(_NoiseBase, sampler_NoiseBase, uvwShape, 0);
    float4 detailNoise = SAMPLE_TEXTURE3D_LOD(_NoiseDetail, sampler_NoiseDetail, uvwDetail, 0);

    // Edge falloff
    const float containerEdgeFadeDst = 10;
    float dstFromEdgeX = min(containerEdgeFadeDst, min(rayPos.x - _CloudBoundsMin.x, _CloudBoundsMax.x - rayPos.x));
    float dstFromEdgeZ = min(containerEdgeFadeDst, min(rayPos.z - _CloudBoundsMin.z, _CloudBoundsMax.z - rayPos.z));
    float edgeWeight = min(dstFromEdgeZ, dstFromEdgeX) / containerEdgeFadeDst;

    float gMin = Remap(weatherMap.x, 0, 1, 0.1, 0.6);
    float gMax = Remap(weatherMap.x, 0, 1, gMin, 0.9);
    float heightPercent = (rayPos.y - _CloudBoundsMin.y) / size.y;
    float heightGradient = saturate(Remap(heightPercent, 0.0, gMin, 0, 1)) *saturate(Remap(heightPercent, 1, gMax, 0, 1));
    float heightGradient2 = saturate(Remap(heightPercent, 0.0, weatherMap.r, 1, 0)) *saturate(Remap(heightPercent, 0.0, gMin, 0, 1));
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

float3 lightmarch(float3 position, float3 rayDir)
{
    float3 dirToLight = normalize(_MainLightPosition).xyz;
                
    float dstInsideBox = rayBoxDst(_CloudBoundsMin, _CloudBoundsMax, position, dirToLight).y;
    float stepSize = dstInsideBox / 8;
    float totalDensity = 0;

    float LoV = dot(-rayDir, normalize(_MainLightPosition.xyz));
    // 2-lobe HG phase
    float3 phaseVal = lerp(HenyeyGreenStein(LoV, _G1), HenyeyGreenStein(LoV, _G2), _Alpha);

    for (int step = 0; step < 8; step++) {
        position += dirToLight * stepSize; 
        totalDensity += max(0, sampleDensity(position));
    }
    float transmittance = exp(-totalDensity * stepSize * _LightAbsorptionTowardSun);

    // Remap transmittance to 3 color levels
    float3 cloudColor = lerp(_ColA, _MainLightColor, saturate(transmittance * _ColorScaleA));
    cloudColor = lerp(_ColB, cloudColor, saturate(pow(transmittance * _ColorScaleB, 3))) * _SunIntensity;

    return _DarknessThreshold + transmittance * (1 - _DarknessThreshold) * cloudColor * phaseVal;
}

float4 raymarch(float3 rayOrigin, float3 rayDir, float dstLimit)
{
    if (dstLimit <= 0)
        return float4(0, 0, 0, 1.0);
    
    const float sizeLoop = 128;
    float transmittance = 1.0;
    float3 lightEnergy = 0;
    float dstTravelled = 0;
    float sumDensity = 0;
    
    for (int j = 0; j < sizeLoop; ++j)
    {
        if (dstTravelled < dstLimit)
        {
            float3 rayPos = rayOrigin + rayDir * dstTravelled;
            float density = sampleDensity(rayPos);
            sumDensity += density;
            if (density > 0)
            {
                transmittance *= exp(-density * _RayStep * _LightAbsorptionThroughCloud);
                float3 lightTransmittance = lightmarch(rayPos, rayDir);
                float powderEffect = 1.0 - exp(-2.0 * sumDensity * _RayStep * _LightAbsorptionThroughCloud * _PowderEffectScale);
                lightEnergy += density * _RayStep * 2.0 * transmittance * powderEffect * lightTransmittance;
            }
        }
        else
            break;
        dstTravelled += _RayStep;
    }
    
    return float4(lightEnergy, transmittance);
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

    // Jitter sample points to avoid banding
    float blueNoise = SAMPLE_TEXTURE2D(_BlueNoise, sampler_BlueNoise, input.uv).r;
    entryPoint += worldViewDir * blueNoise * _RayOffsetStrength;

    return raymarch(entryPoint, worldViewDir, dstLimit);
}

#endif