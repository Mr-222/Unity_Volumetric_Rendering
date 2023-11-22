#ifndef HELPERS_HLSL
#define HELPERS_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

// https://www.shadertoy.com/view/4djSRW
float rand(float2 p){
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float ShadowAtten(float3 worldPosition)
{
    return MainLightRealtimeShadow(TransformWorldToShadowCoord(worldPosition));
}

float3 GetWorldPosFromUV(float2 uv)
{
    #if UNITY_REVERSED_Z
        float depth = SampleSceneDepth(uv);
    #else
        // Adjust z to match NDC for OpenGL
        // See https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@12.0/manual/writing-shaders-urp-reconstruct-world-position.html
        float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
    #endif
    return ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
}


#endif