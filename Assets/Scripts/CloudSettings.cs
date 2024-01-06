using System;
using UnityEngine;

[Serializable]
public class CloudSettings
{
    public Material material;
    public RayMarch rayMarchSetting;
    public Lighting lightingSetting;
    public CloudShape cloudShapeSetting;
    
    [Serializable]
    public struct RayMarch
    {
        public Texture2D blueNoise;
        public float stepSize;
        public float rayStep;
        public float rayOffsetStrength;
    }

    [Serializable]
    public struct Lighting
    {
        public Vector4 phaseParams;
        public float lightAbsorptionThroughCloud;
        public float lightAbsorptionTowardSun;
        public Color darknessThreshold;
        public Color colA;
        public Color colB;
        public float colorScaleA;
        public float colorScaleB;
    }

    [Serializable]
    public struct CloudShape
    {
        public Texture2D maskNoise;
        public Texture2D weatherMap;
        public Texture3D baseNoise;
        public Texture3D detailNoise;
        public Vector3 shapeTiling;
        public Vector3 detailTiling;
        public float shapeSpeed;
        public float detailSpeed;
        public float detailWeights;
        public float heightWeights;
        public Vector4 shapeNoiseWeights;
        public float densityOffset;
        public float densityMultiplier;
    }

    public void SetProperties()
    {
        if (material == null) return;
        
        // Raymarch settings
        material.SetTexture("_BlueNoise", rayMarchSetting.blueNoise);
        material.SetFloat("_Step", rayMarchSetting.stepSize);
        material.SetFloat("_RayStep", rayMarchSetting.rayStep);
        material.SetFloat("_RayOffsetStrength", rayMarchSetting.rayOffsetStrength);
        
        // Lighting settings
        material.SetVector("_PhaseParams", lightingSetting.phaseParams);
        material.SetFloat("_LightAbsorptionThroughCloud", lightingSetting.lightAbsorptionThroughCloud);
        material.SetFloat("_LightAbsorptionTowardSun", lightingSetting.lightAbsorptionTowardSun);
        material.SetVector("_DarknessThreshold", lightingSetting.darknessThreshold);
        material.SetVector("_ColA", lightingSetting.colA);
        material.SetVector("_ColB", lightingSetting.colB);
        material.SetFloat("_ColorScaleA", lightingSetting.colorScaleA);
        material.SetFloat("_ColorScaleB", lightingSetting.colorScaleB);
        
        // Cloud shape settings
        material.SetTexture("_MaskNoise", cloudShapeSetting.maskNoise);
        material.SetTexture("_WeatherMap", cloudShapeSetting.weatherMap);
        material.SetTexture("_NoiseBase", cloudShapeSetting.baseNoise);
        material.SetTexture("_NoiseDetail", cloudShapeSetting.detailNoise);
        material.SetVector("_ShapeTiling", cloudShapeSetting.shapeTiling);
        material.SetVector("_DetailTiling", cloudShapeSetting.detailTiling);
        material.SetFloat("_ShapeSpeed", cloudShapeSetting.shapeSpeed);
        material.SetFloat("_DetailSpeed", cloudShapeSetting.detailSpeed);
        material.SetFloat("_DetailWeights", cloudShapeSetting.detailWeights);
        material.SetFloat("_HeightWeights", cloudShapeSetting.heightWeights);
        material.SetVector("_ShapeNoiseWeights", cloudShapeSetting.shapeNoiseWeights);
        material.SetFloat("_DensityOffset", cloudShapeSetting.densityOffset);
        material.SetFloat("_DensityMultiplier", cloudShapeSetting.densityMultiplier);
    }
}