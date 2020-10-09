
Shader "Hidden/Custom/ComputeCurvDir"
{
    //曲面方向（主曲率を計算してテクスチャに書き込むシェーダ

    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

	TEXTURE2D(_InputColorTexture);
	SAMPLER(sampler_InputColorTexture);
	float4 _InputColorTexture_TexelSize;

	TEXTURE2D(_CameraDepthTexture);
	SAMPLER(sampler_CameraDepthTexture);
	float4 _CameraDepthTexture_TexelSize;

	TEXTURE2D(_CameraNormalTexture);
	SAMPLER(sampler_CameraNormalTexture);
	float4 _CameraNormalTexture_TexelSize;

    //固有ベクトルを計算します
    void eigenVector(in float2x2 A, out float2 v1, out float2 v2) {
            float lamda1, lamda2;
            float a = A[0][0];
            float b = A[0][1];
            float c = A[1][0];
            float d = A[1][1];

            float discriminant = (a+b)*(a+b) - 4*(a*d - b*c); //判別式

            if (discriminant > 0) { //固有値に複素数が入らないとき
                float lamda1 = ( (a+b) + sqrt(discriminant) ) * .5;
                float lamda2 = ( (a+b) - sqrt(discriminant) ) * .5;

                v1 = float2(b, a-lamda1);
                v2 = float2(b, a-lamda2);
                
            }else { //固有値に複素数がまざってしまうとき
                float lamda1 = (a+b) * .5;
                float lamda2 = (a+b) * .5;

                v1 = float2(b, a-lamda1);
                v2 = float2(b, a-lamda2);
            }
    }

    float4 Frag(Varyings input) : SV_Target
    {

		const float2 uv = input.uv;
		const float4 inputColor = SAMPLE_TEXTURE2D(_InputColorTexture, sampler_InputColorTexture, uv);
		const float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
		const float3 normal = SAMPLE_TEXTURE2D(_CameraNormalTexture, sampler_CameraNormalTexture, uv).xyz;
		const float linearDepth = Linear01Depth(depth, _ZBufferParams);
		const float viewZ = LinearEyeDepth(depth, _ZBufferParams);

        //Umenhoffer, T., Lengyel, Z., & Szécsi, L. (2013). Screen space features for real-time hatching synthesis.
        //https://www.google.com/search?q=screen+space+features+for+real-time+hatching+synthesis&oq=screen+s&aqs=chrome.2.69i57j69i59j35i39j0l4j69i60.6177j0j7&sourceid=chrome&ie=UTF-8
        const float dx = 1.f / _ScreenParams.x;
        const float dy = 1.f / _ScreenParams.y;

        sampler_CameraNormalTexture = sampler_LinearClamp;
        float offset = 1;
        float3 n_rgt = SAMPLE_TEXTURE2D(_CameraNormalTexture, sampler_CameraNormalTexture, uv + float2( dx,   0)*offset).xyz;
        float3 n_lft = SAMPLE_TEXTURE2D(_CameraNormalTexture, sampler_CameraNormalTexture, uv + float2(-dx,   0)*offset).xyz;
        float3 n_top = SAMPLE_TEXTURE2D(_CameraNormalTexture, sampler_CameraNormalTexture, uv + float2(  0,  dy)*offset).xyz;
        float3 n_btm = SAMPLE_TEXTURE2D(_CameraNormalTexture, sampler_CameraNormalTexture, uv + float2(  0, -dy)*offset).xyz;

        float2 dndx = 0.5*(n_rgt.xy - n_lft.xy);
        float2 dndy = 0.5*(n_top.xy - n_btm.xy);
        float2x2 H = { dndx.x, dndx.y, dndy.x, dndy.y };
        float2 v1, v2;
        eigenVector(H, v1, v2); //固有ベクトルを求める

        //v2が主方向ベクトルなので
        float4 outColor = float4(v2, 0.0f, 0.0f);
        
        return outColor;
    }

    ENDHLSL

    SubShader
    {
        Pass
        {
            Name "ComputeCurvDir"

            ZWrite Off
            ZTest Off
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment Frag
                #pragma vertex Vert
            ENDHLSL
        }
    }
    Fallback Off
}
