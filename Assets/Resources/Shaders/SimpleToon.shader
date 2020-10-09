Shader "Unlit/SimpleToon"
{
    Properties
    {
        _LineWidth( "Line Width", Range( 0.0, 10.0 ) ) = 0.01
        _LineColor( "Line Color", Color ) = ( 0.0, 0.0, 0.0, 1.0 )

        _MainTex( "MainColor Texture", 2D ) = "white" {}
        _ShadowTex ("ShadowColor Texture", 2D) = "white" {}
        
        _texScale( "texture scale", Range( .0, 100.0 ) ) = 7.0 //これを使うと一応マテリアル毎にハッチの細かさを変えられる

        _hatchTex0( "hatch Texture 0", 2D ) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }
        LOD 100

        Pass
        {
            Name "Outline"

            Cull Front
            ZWrite On

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float       _LineWidth;
            float4      _LineColor;

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
                float4 color    : COLOR;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                VertexPositionInputs vertexData = GetVertexPositionInputs( (input.vertex + float4( _LineWidth * input.normal, 0.0f )).xyz );
                output.vertex = vertexData.positionCS;

                output.color = _LineColor;
                return output;
            }

            float4 frag( Varyings input ) : SV_Target {
                return input.color;
            }
                ENDHLSL
        }

        Pass
        {
            Name "Shading"

            Tags{ "LightMode" = "UniversalForward" }
            Cull Back

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            sampler2D   _MainTex;
            float4      _MainTex_ST;
            sampler2D   _ShadowTex;
            float4      _ShadowTex_ST;

            float       _texScale;
            sampler2D   _hatchTex0;

            TEXTURE2D( _CameraNormalTexture );
            SAMPLER( sampler_CameraNormalTexture );

            TEXTURE2D( _ComputeCurvDirTexture );
            SAMPLER( sampler_ComputeCurvDirTexture );

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;


            struct Attributes
            {
                float4 vertex       : POSITION;
                float3 normal       : NORMAL;
                float4 tangent      : TANGENT;
                float2 texcoord     : TEXCOORD0;
                float2 lightmapUV   : TEXCOORD1;
            };

            struct Varyings
            {
                float4 vertex       : SV_POSITION;  // 同時座標
                float3 wPosition    : POSITION1;    // ワールド空間座標
                float4 sPosition    : POSITION2;    // スクリーン座標
                float3 wNormal      : NORMAL;       // ワールド空間法線
                float3 wTangent     : TANGENT;      // ワールド空間接線
                float4 texCoord0    : TEXCOOR0;     // テクスチャ座標（xy : メインカラー、zw : シャドウカラー）
                float4 shadowCoord  : TEXCOOR2;     // シャドウ用座標
                DECLARE_LIGHTMAP_OR_SH( lightmapUV, vertexSH, 1 ); // 環境光
            };

            Varyings vert( Attributes input )
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexData = GetVertexPositionInputs( input.vertex.xyz );
                VertexNormalInputs   normalData = GetVertexNormalInputs( input.normal, input.tangent );

                output.vertex       = vertexData.positionCS;
                output.wPosition    = vertexData.positionWS;
                output.sPosition    = ComputeScreenPos( output.vertex );
                output.wNormal      = normalData.normalWS.xyz;
                output.wTangent     = normalData.tangentWS.xyz;
                output.texCoord0.xy = TRANSFORM_TEX( input.texcoord.xy, _MainTex ).xy;
                output.texCoord0.zw = TRANSFORM_TEX( input.texcoord.xy, _ShadowTex ).xy;

                #if defined(_MAIN_LIGHT_SHADOWS)
                    output.shadowCoord = GetShadowCoord( vertexData );
                #else
                    output.shadowCoord = float4( 0.0, 0.0, 0.0, 0.0 );
                #endif

                OUTPUT_LIGHTMAP_UV( input.lightmapUV, unity_LightmapST, output.lightmapUV );
                OUTPUT_SH( normalData.normalWS.xyz, output.vertexSH );

                return output;
            }

            //回転行列
            //https://thebookofshaders.com/08/?lan=jp
            float2x2 rotate2d(float _angle){
                return float2x2(cos(_angle),-sin(_angle),
                                sin(_angle),cos(_angle));
            }

            float dirToAngle(float2 _dir) {
                float angle = atan2(_dir.y, _dir.x);
                return angle;
            }

            //回転後のuvをくれる関数
            float2 rotatedUv(in float2 _uv, in float _angle) {
                float2 uv = _uv;
                uv -= 0.5;
                uv = mul( rotate2d(_angle), uv );
                uv += 0.5;
                return uv;
            }

            float2 getUvStair(in float2 _uv, float2 _scale, float2 _offset) {
                return floor(_uv*_scale+_offset)/_scale + 0.5/_scale;
            }

            float2 getUvTile(in float2 _uv, float2 _scale, float2 _offset) {
                return frac(_uv*_scale+_offset);
            }

            //六角タイルを作成する関数. 以下を参考にした
            //https://qiita.com/edo_m18/items/37d8773a5295bc6aba3d
            void outUvHex(in float2 _uv, in float2 _scale, in float2 _offset, out float2 uvHexStair, out float2 uvHexTile) {
                _uv *= _scale;
                _uv += _offset;
                
                float3 col = float3(0,0,0);
                float2 r = normalize(float2(1.0, 1.73));
                float2 h = r * 0.5;
                float2 a = fmod(_uv, r) - h;
                float2 b = fmod(_uv - h, r) - h;
                
                uvHexTile = length(a) < length(b) ? a : b;
                float2 id = _uv - uvHexTile;

                uvHexStair = id / _scale;
                uvHexTile *= 2.6;
                uvHexTile += 0.5;
            }

            //デバッグ用関数
            float rect(float2 _st) {
                float w = 0.1;
                float h = 0.49;
                    
                float pct = step(_st.x, 0.5+w);
                pct *= step(1.-_st.x, 0.5+w);
                pct *= step(_st.y, 0.5+h);
                pct *= step(1.-_st.y, 0.5+h);
                
                return pct;
            }

            //ハッチング状のデバッグ用関数
            float scratch(float2 _st) {
                float2 scale;
                scale.x = 9.904;
                scale.y = 1.;

                float2 st = _st + float2(0.03, 0.0121);
                float pct;
                st.x = clamp(st.x, 0.214, 0.826);
                st.y = clamp(st.y, 0., 1.);
                st *= scale;
                st = frac(st);

                float w, h;
                w = 2.944;
                h = 1.328;

                st -= 0.5;
                st.x *= w;
                st.y *= h;
                st += 0.5;

                pct = sin(clamp(st.x, 0.,1.) * PI);
                pct = max(0., pct);
                pct *= sin(clamp(st.y, 0.,1.) * PI);

                return pct;
            }

            float hexDist(float2 p) {
                p = abs(p);
                float d = dot(p, normalize(float2(1.0, 1.73)));
                return max(d, p.x);
            }

            float getHexGridLine(in float2 _uvHexTile) {
                float y = 0.5 - (hexDist(_uvHexTile-0.5));
                float c = smoothstep(-0.2, 0.1, y);
                return 0.8 * (1. - saturate(c));
            }

            float getHatch(in float2 _uv) {
                float clip = 1.-dot(_uv-0.5, _uv-0.5);
                clip = step(0.65, clip);
                float2 uv = clamp(_uv, 0.,1.);

                float texval = tex2D( _hatchTex0, uv).r;

                return (1. - texval) * clip;
            }
                        
            float4 frag( Varyings input ) : SV_Target
            {

                const float2 st = input.sPosition.xy / input.sPosition.w;
                float aspectRatio = _ScreenParams.x/_ScreenParams.y;

                float2 scale = float2(_texScale, _texScale);
                scale.x *= aspectRatio;

                //-----------------------------------------------------------------------for文で書きたかったけどうまく動かなかったです。
                float2 CurvDir = SAMPLE_TEXTURE2D(_ComputeCurvDirTexture, sampler_ComputeCurvDirTexture, st).xy;
                float pct = 0; //最終的にハッチング模様を格納する場所
                float lineCol = 0;
                float2 offset;
                float2 uvHexStair; //タイルのid
                float2 uvHexTile; //タイルのuv座標
                float2 r_uvHexTile; //回転後のタイルのuv座標
                float2 stairedCurvDir; //六角タイルでサンプリングする主方向
                float hole, hatch;
                float2 flatSurfaceDir = float2(1, 0.5); //フラットな面に指向性を持たせる方向
                    //-------------------------
                    offset = float2(0.,0.); //タイルの座標ををずらす値
                    outUvHex(st, scale, offset, uvHexStair, uvHexTile); //六角タイルを得る
                    
                    //六角タイルで主方向のサンプリング
                    stairedCurvDir = SAMPLE_TEXTURE2D(_ComputeCurvDirTexture, sampler_ComputeCurvDirTexture, uvHexStair).xy;

                    //サンプリングしそこなった部分を埋める. holeが1のときだけうめてくれる。
                    hole = step(length(stairedCurvDir), 0.000001); 
                    stairedCurvDir = lerp(stairedCurvDir, CurvDir, hole);
                    uvHexStair = lerp(uvHexStair, st, hole);

                    //フラットな面に指向性を持たせる
                    stairedCurvDir += flatSurfaceDir * 0.000001;
                    
                    //回転後の六角タイルのuv値を得る
                    r_uvHexTile = rotatedUv(uvHexTile, dirToAngle(stairedCurvDir)+PI*0.5);

                    //ハッチングテクスチャの値を受け取る
                    pct += getHatch(r_uvHexTile);
                    pct = saturate(pct);

                    //-------------------------以下offsetを変えておなじことを繰り返す
                    offset = float2(0.,0.3);
                    outUvHex(st, scale, offset, uvHexStair, uvHexTile);

                    stairedCurvDir = SAMPLE_TEXTURE2D(_ComputeCurvDirTexture, sampler_ComputeCurvDirTexture, uvHexStair).xy;
                    hole = step(length(stairedCurvDir), 0.000001);
                    stairedCurvDir = lerp(stairedCurvDir, CurvDir, hole);
                    uvHexStair = lerp(uvHexStair, st, hole);
                    stairedCurvDir += flatSurfaceDir * 0.000001;
                    
                    r_uvHexTile = rotatedUv(uvHexTile, dirToAngle(stairedCurvDir)+PI*0.5);
                    hatch = getHatch(r_uvHexTile);
                    pct = lerp(pct, hatch, hatch);
                    pct = saturate(pct);

                    //-------------------------以下offsetを変えておなじことを繰り返す
                    offset = float2(0.25,0.15);
                    outUvHex(st, scale, offset, uvHexStair, uvHexTile);

                    stairedCurvDir = SAMPLE_TEXTURE2D(_ComputeCurvDirTexture, sampler_ComputeCurvDirTexture, uvHexStair).xy;
                    hole = step(length(stairedCurvDir), 0.000001);
                    stairedCurvDir = lerp(stairedCurvDir, CurvDir, hole);
                    uvHexStair = lerp(uvHexStair, st, hole);
                    stairedCurvDir += flatSurfaceDir * 0.000001;
                    
                    r_uvHexTile = rotatedUv(uvHexTile, dirToAngle(stairedCurvDir)+PI*0.5);
                    hatch = getHatch(r_uvHexTile);
                    pct = lerp(pct, hatch, hatch);
                    pct = saturate(pct);
                    //-------------------------
                    
                //-----------------------------------------------------------------------


                //-----------------------------------------------------------------------陰影付け
                float4 mainColor    = tex2D( _MainTex, input.texCoord0.xy );
                Light mainLight = GetMainLight( input.shadowCoord );
                
                float4 finalColor = float4(0.,0.,0., 1.);
                //finalColor.rgb *= mainLight.shadowAttenuation; // 影を適用
                //finalColor.rgb += SAMPLE_GI( input.lightmapUV, input.vertexSH, input.wNormal ); // 環境光を適用
                
                //_CameraNormalTextureで焼いたdiffuseを受け取る
                float smoothDiffuse = SAMPLE_TEXTURE2D(_CameraNormalTexture, sampler_CameraNormalTexture, st).a;
                float3 white = float3(1,1,1);
                float shadow = saturate(pct * 2.)*(1-smoothDiffuse)*0.5;
                finalColor.rgb = lerp(saturate(mainColor*1.4), white, 0.1)*smoothDiffuse - saturate(pct * 2.)*(1-smoothDiffuse)*0.5;

                return finalColor;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 5.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "AdditionalTexture"
            Tags { "LightMode" = "AdditionalTexture" }

            Cull Back
            ZWrite ON

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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
                float3 wNormal  : NORMAL;
            };

            Varyings vert( Attributes input )
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexData = GetVertexPositionInputs( input.vertex );
                VertexNormalInputs   normalData = GetVertexNormalInputs( input.normal, input.tangent );

                output.vertex  = vertexData.positionCS;
                //output.wNormal = normalData.normalWS.xyz;
                output.wNormal = mul( ( float3x3 )( UNITY_MATRIX_V ), normalData.normalWS.xyz ); // View space の法線を書き出す

                return output;
            }

            float4 frag( Varyings input ) : SV_Target
            {
                return float4(input.wNormal, 1.0);
            }

            ENDHLSL
        }

    }
}
