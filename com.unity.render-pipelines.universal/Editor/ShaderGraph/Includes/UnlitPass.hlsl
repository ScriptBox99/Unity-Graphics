
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Unlit.hlsl"

void InitializeInputData(Varyings input, out InputData inputData)
{
    inputData = (InputData)0;

    // InputData is only used for DebugDisplay purposes in Unlit, so these are not initialized.
    #if defined(DEBUG_DISPLAY)
    inputData.positionWS = input.positionWS;
    inputData.normalWS = input.normalWS;
    #else
    inputData.positionWS = half3(0, 0, 0);
    inputData.normalWS = half3(0, 0, 1);
    inputData.viewDirectionWS = half3(0, 0, 1);
    #endif
    inputData.shadowCoord = 0;
    inputData.fogCoord = 0;
    inputData.vertexLighting = half3(0, 0, 0);
    inputData.bakedGI = half3(0, 0, 0);
    inputData.normalizedScreenSpaceUV = 0;
    inputData.shadowMask = half4(1, 1, 1, 1);
}

PackedVaryings vert(Attributes input)
{
    Varyings output = (Varyings)0;
    output = BuildVaryings(input);
    PackedVaryings packedOutput = PackVaryings(output);
    return packedOutput;
}

half4 frag(PackedVaryings packedInput) : SV_TARGET
{
    Varyings unpacked = UnpackVaryings(packedInput);
    UNITY_SETUP_INSTANCE_ID(unpacked);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(unpacked);
    SurfaceDescription surfaceDescription = BuildSurfaceDescription(unpacked);

    #if _ALPHATEST_ON
        half alpha = surfaceDescription.Alpha;
        clip(alpha - surfaceDescription.AlphaClipThreshold);
    #elif _SURFACE_TYPE_TRANSPARENT
        half alpha = surfaceDescription.Alpha;
    #else
        half alpha = half(1.0);
    #endif

#if defined(_ALPHAMODULATE_ON)
    surfaceDescription.BaseColor = AlphaModulate(surfaceDescription.BaseColor, alpha);
#endif

#if defined(_DBUFFER)
    ApplyDecalToBaseColor(unpacked.positionCS, surfaceDescription.BaseColor);
#endif

    InputData inputData;
    InitializeInputData(unpacked, inputData);
    // TODO: Mip debug modes would require this, open question how to do this on ShaderGraph.
    //SETUP_DEBUG_TEXTURE_DATA(inputData, input.texCoord1, _MainTex);

    half4 finalColor = UniversalFragmentUnlit(inputData, surfaceDescription.BaseColor, alpha);

    return finalColor;
}
