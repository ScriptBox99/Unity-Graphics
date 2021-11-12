Shader "Hidden/Universal Render Pipeline/TemporalAA"
{
    HLSLINCLUDE
        #pragma exclude_renderers gles

        #pragma multi_compile _ _USE_DRAW_PROCEDURAL

        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Random.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        TEXTURE2D_X(_SourceTex);
        float4 _SourceTex_TexelSize;

        TEXTURE2D_X(_AccumulationTex);
#if defined(USING_STEREO_MATRICES)
        float4x4 _PrevViewProjMStereo[2];
#define _PrevViewProjM  _PrevViewProjMStereo[unity_StereoEyeIndex]
#define _ViewProjM unity_MatrixVP
#else
        float4x4 _ViewProjM;
        float4x4 _PrevViewProjM;
#endif
        half4 _SourceSize;

        half _TemporalAAFrameInfl;

        struct VaryingsCMB
        {
            float4 positionCS    : SV_POSITION;
            float4 uv            : TEXCOORD0;
            UNITY_VERTEX_OUTPUT_STEREO
        };

        VaryingsCMB VertCMB(Attributes input)
        {
            VaryingsCMB output;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

#if _USE_DRAW_PROCEDURAL
            GetProceduralQuad(input.vertexID, output.positionCS, output.uv.xy);
#else
            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
            output.uv.xy = input.uv;
#endif
            float4 projPos = output.positionCS * 0.5;
            projPos.xy = projPos.xy + projPos.w;
            output.uv.zw = projPos.xy;

            return output;
        }

        half2 ClampVelocity(half2 velocity, half maxVelocity)
        {
            half len = length(velocity);
            return (len > 0.0) ? min(len, maxVelocity) * (velocity * rcp(len)) : 0.0;
        }

        // Per-pixel camera velocity
        half2 GetCameraVelocityWithOffset(float4 uv, half2 depthOffsetUv)
        {
            float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_PointClamp, uv.xy + _SourceTex_TexelSize.xy * depthOffsetUv).r;

        #if UNITY_REVERSED_Z
            depth = 1.0 - depth;
        #endif

            depth = 2.0 * depth - 1.0;

            float3 viewPos = ComputeViewSpacePosition(uv.zw, depth, unity_CameraInvProjection);
            float4 worldPos = float4(mul(unity_CameraToWorld, float4(viewPos, 1.0)).xyz, 1.0);
            float4 prevPos = worldPos;

            float4 prevClipPos = mul(_PrevViewProjM, prevPos);
            float4 curClipPos = mul(_ViewProjM, worldPos);

            half2 prevPosCS = prevClipPos.xy / prevClipPos.w;
            half2 curPosCS = curClipPos.xy / curClipPos.w;

            return prevPosCS - curPosCS;
        }

        half3 GatherSample(half sampleNumber, half2 velocity, half invSampleCount, float2 centerUV, half randomVal, half velocitySign)
        {
            half  offsetLength = (sampleNumber + 0.5h) + (velocitySign * (randomVal - 0.5h));
            float2 sampleUV = centerUV + (offsetLength * invSampleCount) * velocity * velocitySign;
            return SAMPLE_TEXTURE2D_X(_SourceTex, sampler_PointClamp, sampleUV).xyz;
        }

        void AdjustBestDepthOffset(inout half bestDepth, inout half bestX, inout half bestY, float2 uv, half currX, half currY)
        {
            // half precision should be fine, as we are only concerned about choosing the better value along sharp edges, so it's
            // acceptable to have banding on continuous surfaces
            half depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_PointClamp, uv.xy + _SourceTex_TexelSize.xy * half2(currX, currY)).r;

#if UNITY_REVERSED_Z
            depth = 1.0 - depth;
#endif

            bool isBest = depth < bestDepth;
            bestDepth = isBest ? depth : bestDepth;
            bestX = isBest ? currX : bestX;
            bestY = isBest ? currY : bestY;
        }

        void AdjustColorBox(inout half3 boxMin, inout half3 boxMax, float2 uv, half currX, half currY)
        {
            half3 color = (SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + _SourceTex_TexelSize.xy * float2(currX, currY)));
            boxMin = min(color, boxMin);
            boxMax = max(color, boxMax);
        }


        half4 DoMotionBlur(VaryingsCMB input, int iterations)
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            float2 uv = UnityStereoTransformScreenSpaceTex(input.uv.xy);
            half2 depthOffsetUv = 0.0f;

            half3 colorCenter = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + _SourceTex_TexelSize.xy * float2(0.0, 0.0));
            half3 boxMax = colorCenter;

            half3 boxMin = colorCenter;

            AdjustColorBox(boxMin, boxMax, uv, -1.0f, -1.0f);
            AdjustColorBox(boxMin, boxMax, uv, 0.0f, -1.0f);
            AdjustColorBox(boxMin, boxMax, uv, 1.0f, -1.0f);
            AdjustColorBox(boxMin, boxMax, uv, -1.0f, 0.0f);
            AdjustColorBox(boxMin, boxMax, uv, 1.0f, 0.0f);
            AdjustColorBox(boxMin, boxMax, uv, -1.0f, 1.0f);
            AdjustColorBox(boxMin, boxMax, uv, 0.0f, 1.0f);
            AdjustColorBox(boxMin, boxMax, uv, 1.0f, 1.0f);

            half bestOffsetX = 0.0f;
            half bestOffsetY = 0.0f;
            half bestDepth = 1.0f;
            AdjustBestDepthOffset(bestDepth, bestOffsetX, bestOffsetY, uv, -1.0f, -1.0f);
            AdjustBestDepthOffset(bestDepth, bestOffsetX, bestOffsetY, uv, 0.0f, -1.0f);
            AdjustBestDepthOffset(bestDepth, bestOffsetX, bestOffsetY, uv, 1.0f, -1.0f);
            AdjustBestDepthOffset(bestDepth, bestOffsetX, bestOffsetY, uv, -1.0f, 0.0f);
            AdjustBestDepthOffset(bestDepth, bestOffsetX, bestOffsetY, uv, 0.0f, 0.0f);
            AdjustBestDepthOffset(bestDepth, bestOffsetX, bestOffsetY, uv, 1.0f, 0.0f);
            AdjustBestDepthOffset(bestDepth, bestOffsetX, bestOffsetY, uv, -1.0f, 1.0f);
            AdjustBestDepthOffset(bestDepth, bestOffsetX, bestOffsetY, uv, 0.0f, 1.0f);
            AdjustBestDepthOffset(bestDepth, bestOffsetX, bestOffsetY, uv, 1.0f, 1.0f);


            depthOffsetUv = half2(bestOffsetX, bestOffsetY);

            half2 velocity = GetCameraVelocityWithOffset(float4(uv, input.uv.zw), depthOffsetUv);
            half randomVal = InterleavedGradientNoise(uv * _SourceSize.xy, 0);


            half3 accum = SAMPLE_TEXTURE2D_X(_AccumulationTex, sampler_LinearClamp, uv + 0.5 * velocity * float2(1, 1)).xyz;
            half3 clampAccum = clamp(accum, boxMin, boxMax);

            half3 color = lerp(clampAccum, colorCenter, _TemporalAAFrameInfl);

#if 0
            float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_PointClamp, uv.xy).r;

#if UNITY_REVERSED_Z
            depth = 1.0 - depth;
#endif

            depth = 2.0 * depth - 1.0;


            //color = lerp(color,saturate(depth).xxx,.25f);


#endif
            //color = depthOffsetUv.x*.5+.5;
            //color = depth;
            //color = half3(saturate(velocity * 10.0f + 0.5f), 0.0f);

            return half4(color, 1.0);
        }


        half4 DoCopy(VaryingsCMB input)
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            float2 uv = UnityStereoTransformScreenSpaceTex(input.uv.xy);

            // seems to require an extra flip
            uv.y = 1.0f - uv.y;

            half3 color = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_PointClamp, uv).xyz;

            return half4(color, 1.0f);
        }


    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "TemporalAA - Accumulate"

            HLSLPROGRAM

                #pragma vertex VertCMB
                #pragma fragment Frag

                half4 Frag(VaryingsCMB input) : SV_Target
                {
                    return DoMotionBlur(input, 2);
                }

            ENDHLSL
        }

        Pass
        {
            Name "TemporalAA - Copy"

            HLSLPROGRAM

                #pragma vertex VertCMB
                #pragma fragment Frag

                half4 Frag(VaryingsCMB input) : SV_Target
                {
                    return DoCopy(input);
                }

            ENDHLSL
        }

    }
}
