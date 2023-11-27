#ifndef MACROS_HLSL
#define MACROS_HLSL

#define DEPTH_01(uv) Linear01Depth(SampleSceneDepth(uv), _ZBufferParams)

#define BLUR_DEPTH_FALLOFF 10000.0f

#endif