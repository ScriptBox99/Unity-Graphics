
void TerrainSplatBlend(float2 controlUV, float2 splatBaseUV, inout TerrainLitSurfaceData surfaceData)
{
    // TODO: triplanar
    // TODO: POM
    float alpha;
    float4 outControl;
    GetSplatData(splatBaseUV, 0, true, surfaceData.albedo, surfaceData.normalData, surfaceData.metallic, surfaceData.smoothness, surfaceData.ao, alpha, outControl);

//    float2 dxuv = ddx(splatBaseUV);
//    float2 dyuv = ddy(splatBaseUV);
//
//    float2 blendUV0 = (controlUV.xy * (_Control0_TexelSize.zw - 1.0f) + 0.5f) * _Control0_TexelSize.xy;
//    float4 blendMasks0 = SAMPLE_TEXTURE2D(_Control0, sampler_Control0, blendUV0);
//    #ifdef _TERRAIN_8_LAYERS
//        float2 blendUV1 = (controlUV.xy * (_Control1_TexelSize.zw - 1.0f) + 0.5f) * _Control1_TexelSize.xy;
//        float4 blendMasks1 = SAMPLE_TEXTURE2D(_Control1, sampler_Control0, blendUV1);
//    #else
//        float4 blendMasks1 = float4(0, 0, 0, 0);
//    #endif
//
//    SampleResults(0, blendMasks0.x);
//    SampleResults(1, blendMasks0.y);
//    SampleResults(2, blendMasks0.z);
//    SampleResults(3, blendMasks0.w);
//    #ifdef _TERRAIN_8_LAYERS
//        SampleResults(4, blendMasks1.x);
//        SampleResults(5, blendMasks1.y);
//        SampleResults(6, blendMasks1.z);
//        SampleResults(7, blendMasks1.w);
//    #endif
//
//#undef SampleNormal
//#undef SampleMasks
//#undef SampleResults
//
//    float weights[_LAYER_COUNT];
//    ZERO_INITIALIZE_ARRAY(float, weights, _LAYER_COUNT);
//
//    #ifdef _MASKMAP
//        #if defined(_TERRAIN_BLEND_HEIGHT)
//            // Modify blendMask to take into account the height of the layer. Higher height should be more visible.
//            float maxHeight = masks[0].z;
//            maxHeight = max(maxHeight, masks[1].z);
//            maxHeight = max(maxHeight, masks[2].z);
//            maxHeight = max(maxHeight, masks[3].z);
//            #ifdef _TERRAIN_8_LAYERS
//                maxHeight = max(maxHeight, masks[4].z);
//                maxHeight = max(maxHeight, masks[5].z);
//                maxHeight = max(maxHeight, masks[6].z);
//                maxHeight = max(maxHeight, masks[7].z);
//            #endif
//
//            // Make sure that transition is not zero otherwise the next computation will be wrong.
//            // The epsilon here also has to be bigger than the epsilon in the next computation.
//            float transition = max(_HeightTransition, 1e-5);
//
//            // The goal here is to have all but the highest layer at negative heights, then we add the transition so that if the next highest layer is near transition it will have a positive value.
//            // Then we clamp this to zero and normalize everything so that highest layer has a value of 1.
//            float4 weightedHeights0 = { masks[0].z, masks[1].z, masks[2].z, masks[3].z };
//            weightedHeights0 = weightedHeights0 - maxHeight.xxxx;
//            // We need to add an epsilon here for active layers (hence the blendMask again) so that at least a layer shows up if everything's too low.
//            weightedHeights0 = (max(0, weightedHeights0 + transition) + 1e-6) * blendMasks0;
//
//            #ifdef _TERRAIN_8_LAYERS
//                float4 weightedHeights1 = { masks[4].z, masks[5].z, masks[6].z, masks[7].z };
//                weightedHeights1 = weightedHeights1 - maxHeight.xxxx;
//                weightedHeights1 = (max(0, weightedHeights1 + transition) + 1e-6) * blendMasks1;
//            #else
//                float4 weightedHeights1 = { 0, 0, 0, 0 };
//            #endif
//
//            // Normalize
//            float sumHeight = GetSumHeight(weightedHeights0, weightedHeights1);
//            blendMasks0 = weightedHeights0 / sumHeight.xxxx;
//            #ifdef _TERRAIN_8_LAYERS
//                blendMasks1 = weightedHeights1 / sumHeight.xxxx;
//            #endif
//        #elif defined(_TERRAIN_BLEND_DENSITY)
//            // Denser layers are more visible.
//            float4 opacityAsDensity0 = saturate((float4(albedo[0].a, albedo[1].a, albedo[2].a, albedo[3].a) - (float4(1.0, 1.0, 1.0, 1.0) - blendMasks0)) * 20.0); // 20.0 is the number of steps in inputAlphaMask (Density mask. We decided 20 empirically)
//            opacityAsDensity0 += 0.001f * blendMasks0;      // if all weights are zero, default to what the blend mask says
//            float4 useOpacityAsDensityParam0 = { _DiffuseRemapScale0.w, _DiffuseRemapScale1.w, _DiffuseRemapScale2.w, _DiffuseRemapScale3.w }; // 1 is off
//            blendMasks0 = lerp(opacityAsDensity0, blendMasks0, useOpacityAsDensityParam0);
//            #ifdef _TERRAIN_8_LAYERS
//                float4 opacityAsDensity1 = saturate((float4(albedo[4].a, albedo[5].a, albedo[6].a, albedo[7].a) - (float4(1.0, 1.0, 1.0, 1.0) - blendMasks1)) * 20.0); // 20.0 is the number of steps in inputAlphaMask (Density mask. We decided 20 empirically)
//                opacityAsDensity1 += 0.001f * blendMasks1;  // if all weights are zero, default to what the blend mask says
//                float4 useOpacityAsDensityParam1 = { _DiffuseRemapScale4.w, _DiffuseRemapScale5.w, _DiffuseRemapScale6.w, _DiffuseRemapScale7.w };
//                blendMasks1 = lerp(opacityAsDensity1, blendMasks1, useOpacityAsDensityParam1);
//            #endif
//
//            // Normalize
//            float sumHeight = GetSumHeight(blendMasks0, blendMasks1);
//            blendMasks0 = blendMasks0 / sumHeight.xxxx;
//            #ifdef _TERRAIN_8_LAYERS
//                blendMasks1 = blendMasks1 / sumHeight.xxxx;
//            #endif
//        #endif // if _TERRAIN_BLEND_HEIGHT
//    #endif // if _MASKMAP
//
//    weights[0] = blendMasks0.x;
//    weights[1] = blendMasks0.y;
//    weights[2] = blendMasks0.z;
//    weights[3] = blendMasks0.w;
//    #ifdef _TERRAIN_8_LAYERS
//        weights[4] = blendMasks1.x;
//        weights[5] = blendMasks1.y;
//        weights[6] = blendMasks1.z;
//        weights[7] = blendMasks1.w;
//    #endif
//
//    surfaceData.albedo = 0;
//    surfaceData.normalData = 0;
//    float3 outMasks = 0;
//    UNITY_UNROLL for (int i = 0; i < _LAYER_COUNT; ++i)
//    {
//        surfaceData.albedo += albedo[i].rgb * weights[i];
//        surfaceData.normalData += normal[i].rgb * weights[i]; // no need to normalize
//        outMasks += masks[i].xyw * weights[i];
//    }
//    surfaceData.smoothness = outMasks.z;
//    surfaceData.metallic = outMasks.x;
//    surfaceData.ao = outMasks.y;
}

void TerrainLitShade(float2 uv, inout TerrainLitSurfaceData surfaceData)
{
    TerrainSplatBlend(uv, uv, surfaceData);
}

void TerrainLitDebug(float2 uv, inout float3 baseColor)
{
#ifdef DEBUG_DISPLAY
    if (_DebugMipMapModeTerrainTexture == DEBUGMIPMAPMODETERRAINTEXTURE_CONTROL)
        baseColor = GetTextureDataDebug(_DebugMipMapMode, uv, _Control0, _Control0_TexelSize, _Control0_MipInfo, baseColor);
    else if (_DebugMipMapModeTerrainTexture == DEBUGMIPMAPMODETERRAINTEXTURE_LAYER0)
        baseColor = GetTextureDataDebug(_DebugMipMapMode, uv * _Splat0_ST.xy + _Splat0_ST.zw, _Splat0, _Splat0_TexelSize, _Splat0_MipInfo, baseColor);
    else if (_DebugMipMapModeTerrainTexture == DEBUGMIPMAPMODETERRAINTEXTURE_LAYER1)
        baseColor = GetTextureDataDebug(_DebugMipMapMode, uv * _Splat1_ST.xy + _Splat1_ST.zw, _Splat1, _Splat1_TexelSize, _Splat1_MipInfo, baseColor);
    else if (_DebugMipMapModeTerrainTexture == DEBUGMIPMAPMODETERRAINTEXTURE_LAYER2)
        baseColor = GetTextureDataDebug(_DebugMipMapMode, uv * _Splat2_ST.xy + _Splat2_ST.zw, _Splat2, _Splat2_TexelSize, _Splat2_MipInfo, baseColor);
    else if (_DebugMipMapModeTerrainTexture == DEBUGMIPMAPMODETERRAINTEXTURE_LAYER3)
        baseColor = GetTextureDataDebug(_DebugMipMapMode, uv * _Splat3_ST.xy + _Splat3_ST.zw, _Splat3, _Splat3_TexelSize, _Splat3_MipInfo, baseColor);
    #ifdef _TERRAIN_8_LAYERS
        else if (_DebugMipMapModeTerrainTexture == DEBUGMIPMAPMODETERRAINTEXTURE_LAYER4)
            baseColor = GetTextureDataDebug(_DebugMipMapMode, uv * _Splat4_ST.xy + _Splat4_ST.zw, _Splat4, _Splat4_TexelSize, _Splat4_MipInfo, baseColor);
        else if (_DebugMipMapModeTerrainTexture == DEBUGMIPMAPMODETERRAINTEXTURE_LAYER5)
            baseColor = GetTextureDataDebug(_DebugMipMapMode, uv * _Splat5_ST.xy + _Splat5_ST.zw, _Splat5, _Splat5_TexelSize, _Splat5_MipInfo, baseColor);
        else if (_DebugMipMapModeTerrainTexture == DEBUGMIPMAPMODETERRAINTEXTURE_LAYER6)
            baseColor = GetTextureDataDebug(_DebugMipMapMode, uv * _Splat6_ST.xy + _Splat6_ST.zw, _Splat6, _Splat6_TexelSize, _Splat6_MipInfo, baseColor);
        else if (_DebugMipMapModeTerrainTexture == DEBUGMIPMAPMODETERRAINTEXTURE_LAYER7)
            baseColor = GetTextureDataDebug(_DebugMipMapMode, uv * _Splat7_ST.xy + _Splat7_ST.zw, _Splat7, _Splat7_TexelSize, _Splat7_MipInfo, baseColor);
    #endif
#endif
}
