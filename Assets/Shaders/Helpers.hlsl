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
    #if UNITY_REVERSED_Z
        float depth = SampleSceneDepth(uv);
    #else
        // Adjust Z to match NDC for OpenGL ([-1, 1])
        float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
    #endif
                
    float3 worldPos = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
    return worldPos;
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

// Returns (dstToBox, dstInsideBox). If ray misses box, dstInsideBox will be zero
float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 rayDir) {
    // Adapted from: http://jcgt.org/published/0007/03/04/
    float3 t0 = (boundsMin - rayOrigin) / rayDir;
    float3 t1 = (boundsMax - rayOrigin) / rayDir;
    float3 tmin = min(t0, t1);
    float3 tmax = max(t0, t1);
    float dstA = max(max(tmin.x, tmin.y), tmin.z);
    float dstB = min(min(tmax.x, tmax.y), tmax.z);

    // CASE 1: ray intersects box from outside (0 <= dstA <= dstB)
    // dstA is dist to nearest intersection, dstB dist to far intersection

    // CASE 2: ray intersects box from inside (dstA < 0 < dstB)
    // dstA is the dist to intersection behind the ray, dstB is dist to forward intersection

    // CASE 3: ray misses box (dstA > dstB)
    float dstToBox = max(0, dstA);
    float dstInsideBox = max(0, dstB - dstToBox);
    return float2(dstToBox, dstInsideBox);
}

float2 rayBoxDst_new(float3 boundsMin, float3 boundsMax, 
                            //世界相机位置      反向世界空间光线方向
                            float3 rayOrigin, float3 invRaydir) 
{
    float3 t0 = (boundsMin - rayOrigin) * invRaydir;
    float3 t1 = (boundsMax - rayOrigin) * invRaydir;
    float3 tmin = min(t0, t1);
    float3 tmax = max(t0, t1);

    float dstA = max(max(tmin.x, tmin.y), tmin.z); //进入点
    float dstB = min(tmax.x, min(tmax.y, tmax.z)); //出去点

    float dstToBox = max(0, dstA);
    float dstInsideBox = max(0, dstB - dstToBox);
    return float2(dstToBox, dstInsideBox);
}
//
// float Remap(float original_value, float original_min, float original_max, float target_min, float target_max)
// {
//     return target_min + (original_value - original_min) / (original_max - original_min) * (target_max - target_min);
// }

float Remap(float original_value, float original_min, float original_max, float new_min, float new_max)
{
    return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
}

float3 convertToBoxSpace(float3 p, float3 boxMin, float3 boxMax)
{
    float3 boxSize = boxMax - boxMin;
    float3 pInBox = p - boxMin;
    float3 pInBoxNormalized = pInBox / boxSize;
    return pInBoxNormalized;
}

#endif