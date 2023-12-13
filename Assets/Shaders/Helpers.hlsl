#ifndef HELPERS_HLSL
#define HELPERS_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

// https://www.shadertoy.com/view/4djSRW
float rand(float2 p){
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float MainLightShadowAtten(float3 worldPosition)
{
    return MainLightRealtimeShadow(TransformWorldToShadowCoord(worldPosition));
}

float3 GetWorldPosFromUV(float2 uv)
{
    float depth = SampleSceneDepth(uv);
    return ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
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

#endif