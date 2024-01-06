Shader "Unlit/DebugVolume"
{
    Properties
    {
        _VolumeTex ("3D Texture", 3D) = "black" {}
        _Offset ("3D Offset", Vector) = (0, 0, 0)
        _Scale ("3D Scale", Vector) = (1, 1, 1)
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" }
        Blend One OneMinusSrcAlpha
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 worldVertex : TEXCOORD0;
            };

            sampler3D _VolumeTex;
            float3 _Offset;
            float3 _Scale;

            v2f vert (appdata v)
            {
                v2f o;
                
                o.worldVertex = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            float4 BlendUnder(float4 color, float4 newColor)
            {
                color.rgb += (1.0 - color.a) * newColor.a * newColor.rgb;
                color.a += (1.0 - color.a) * newColor.a;
                return color;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 tex3DUvw = float3(i.worldVertex + _Offset) * _Scale;
                float4 colorSample = tex3D(_VolumeTex, tex3DUvw);
                
                return colorSample;
            }
            ENDCG
        }
    }
}