Shader "Hidden/Custom/CameraNormalTexture"
{
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True"
        }
        LOD 100

        Pass
        {
            Name "CameraNormalTexture"

            Cull Back
            ZWrite On

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 vertex   : POSITION;
                float3 normal   : NORMAL;
                float4 tangent  : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 vertex   : SV_POSITION;
                float3 normal  : NORMAL;
                float3 wNormal  : TANGENT;
                float4 shadowCoord  : TEXCOORD0;     // シャドウ用座標
            };

            Varyings vert( Attributes input )
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexData = GetVertexPositionInputs( input.vertex.xyz );
                VertexNormalInputs   normalData = GetVertexNormalInputs( input.normal, input.tangent );

                output.vertex  = vertexData.positionCS;
                output.normal = mul( ( float3x3 )( UNITY_MATRIX_V ), normalData.normalWS.xyz ); // View space の法線を書き出す
                output.wNormal = normalData.normalWS.xyz;

                #if defined(_MAIN_LIGHT_SHADOWS)
                    output.shadowCoord = GetShadowCoord( vertexData );
                #else
                    output.shadowCoord = float4( 0.0, 0.0, 0.0, 0.0 );
                #endif

                return output;
            }

            float4 frag( Varyings input ) : SV_Target
            {   
                Light mainLight = GetMainLight( input.shadowCoord );
                float diffuse = dot( mainLight.direction, input.wNormal );

                return float4(input.normal.xyz, diffuse); //ついでにディフューズも送る
            }

            ENDHLSL
        }

        
    }
}
