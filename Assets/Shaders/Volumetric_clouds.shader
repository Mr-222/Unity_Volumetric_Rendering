Shader "Custom/VolumetricClouds"
{
    Properties
    {
        _NumSteps ("Number of raymarch steps", Range(5, 100)) = 64
    	_StepSize ("Raymarch Step size", Range(0.001, 0.3)) = 0.02
    	_DensityScale ("Density scale", Range(0.1, 1)) = 0.5
    	_VolumeTex ("Volume texture", 3D) = "white" {}
    	_Offset ("Offset", Vector) = (0, 0, 0)
    	_NumLightSteps ("Number of light steps", Range(5, 100)) = 15
    	_LightStepSize ("Light step size", Range(0.001, 0.3)) = 0.06
    	_LightAbsorb ("Light absorb",Float) = 2
    	_DarknessThreshold ("Darkness threshold", Range(0, 1)) = 0.15
    	_Transmittance ("Transmittance", Range(0, 1)) = 1
    	_Color ("Cloud color", Color) = (1, 1, 1)
    	_ShadowColor ("Shadow color", Color) = (0, 0, 0.2)
    }
    SubShader 
    {
        Tags 
        { 
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" ="Transparent" 
        }
        
        Pass
        {
        	Name "Volumetric cloud"
        	
        	Cull Back
			ZWrite Off
			ZTest Always
			Blend SrcAlpha OneMinusSrcAlpha
        	
        	HLSLPROGRAM
        
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			#pragma vertex vert
			#pragma fragment frag

	        CBUFFER_START(UnityPerMaterial)
	        float _NumSteps;
	        float _StepSize;
	        float _DensityScale;
	        TEXTURE3D(_VolumeTex);
			SAMPLER(sampler_VolumeTex);
			float3 _Offset;
			float _NumLightSteps;
			float _LightStepSize;
			float _LightAbsorb;
			float _DarknessThreshold;
			float _Transmittance;
			float3 _Color;
			float3 _ShadowColor;
	        CBUFFER_END;

	        struct Attributes
	        {
	            float4 positionOS : POSITION;
	            float2 uv         : TEXCOORD0;
	        };

	        struct Varyings
	        {
	            float4 positionCS : SV_POSITION;
        		float3 positionOS : TEXCOORD0;
	            float2 uv         : TEXCOORD1;
	        };

	        Varyings vert(Attributes input)
	        {
	            Varyings output;
	            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
        		output.positionOS = input.positionOS.xyz;
	            output.uv = input.uv;

	            return output;
	        }

	        void raymarch( float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                     float densityScale, Texture3D volumeTex, SamplerState volumeSampler,
                     float3 offset, float numLightSteps, float lightStepSize, float3 lightDir,
                     float lightAbsorb, float darknessThreshold, float transmittance, out float3 result )
			{
	        	float density = 0;
	        	float finalLight = 0;

	        	for (int i = 0; i < numSteps; ++i)
	        	{
	        		rayOrigin += rayDirection * stepSize;
	        		float3 samplePos = rayOrigin + offset;
	        		float sampledDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, samplePos).r;
	        		density += sampledDensity * densityScale;

	        		// Light loop
	        		float3 lightRayOrigin = samplePos;
	        		float lightAccumulation = 0;
	        		for (int j = 0; j < numLightSteps; ++j)
	        		{
	        			lightRayOrigin -= lightDir * lightStepSize;
	        			float lightDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, lightRayOrigin).r;
	        			// Higher density, less light reach to the camera
	        			lightAccumulation += lightDensity;
	        		}
	        		float lightTransmission = exp(-lightAccumulation);
	        		// Shadow tends to the darkness threshold as lightAccumulation rises
	        		float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);

	        		finalLight += density * transmittance * shadow;

	        		// Initially a param its value is updated at each step by lightAbsorb, this sets light lost by scattering
	        		transmittance *= exp(-density * lightAbsorb);
	        	}

	        	float transmission = exp(-density);

	        	result = float3(finalLight, transmission, transmittance);
			}
			
	        float4 frag(Varyings input) : SV_Target
	        {
	            float3 cameraPos = _WorldSpaceCameraPos;
        		cameraPos = TransformWorldToObject(cameraPos);
        		const float3 rayDirection = normalize(input.positionOS - cameraPos);
        		const float3 rayOrigin = input.positionOS;
        		float3 result = 0;
				Light light = GetMainLight();
	        	float3 lightDir = TransformWorldToObject(-light.direction);
	        	
        		raymarch(rayOrigin, rayDirection, _NumSteps, _StepSize,
        			_DensityScale, _VolumeTex, sampler_VolumeTex,_Offset,
        			_NumLightSteps, _LightStepSize, lightDir,
        			_LightAbsorb, _DarknessThreshold, _Transmittance, result);

				float3 color = lerp(_ShadowColor, _Color, result.r);
	        	
        		return float4(color, 1.0 - result.g);
	        }
			
        	ENDHLSL
        }
    }
}

