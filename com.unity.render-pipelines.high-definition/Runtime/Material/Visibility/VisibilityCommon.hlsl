#ifndef VISIBILITY_HLSL
#define VISIBILITY_HLSL

#include "Packages/com.unity.render-pipelines.core/Runtime/GeometryPool/Resources/GeometryPool.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

TEXTURE2D_X_UINT(_VisBufferTexture0);
TEXTURE2D_X_UINT(_VisBufferTexture1);

TEXTURE2D_X_UINT(_VisBufferFeatureTiles);
TEXTURE2D_X_UINT2(_VisBufferMaterialTiles);
TEXTURE2D_X_UINT(_VisBufferBucketTiles);

#define VIS_BUFFER_TILE_LOG2 6
#define VIS_BUFFER_TILE_SIZE (1 <<  VIS_BUFFER_TILE_LOG2) //64

namespace Visibility
{

#define InvalidVisibilityData 0

struct VisibilityData
{
    bool valid;
    uint DOTSInstanceIndex;
    uint primitiveID;
    uint batchID;
};

float3 DebugVisIndexToRGB(uint index)
{
    if (index == 0)
        return float3(0, 0, 0);

    uint maxCol = 512;
    float indexf = sin(816.0f * (index % maxCol)) * 2.0;
    {
        indexf = frac(indexf * 0.011);
        indexf *= indexf + 7.5;
        indexf *= indexf + indexf;
        indexf = frac(indexf);
    }

    float H = indexf;

    //standard hue to HSV
    float R = abs(H * 6 - 3) - 1;
    float G = 2 - abs(H * 6 - 2);
    float B = 2 - abs(H * 6 - 4);
    return saturate(float3(R,G,B));
}

uint PackVisibilityData(in VisibilityData data)
{
    uint packedData = 0;
    packedData |= (data.DOTSInstanceIndex & 0xffff);
    packedData |= (data.primitiveID & 0x7fff) << 16;
    packedData |= (data.valid ? 1 : 0) << 31;
    return packedData;
}

void PackVisibilityData(in VisibilityData data, out uint packedData0, out uint packedData1)
{
    packedData0 = 0;
    packedData0 |= (data.DOTSInstanceIndex & 0xffff);
    packedData0 |= (data.primitiveID & 0x7fff) << 16;
    packedData0 |= (data.valid ? 1 : 0) << 31;
    packedData1 = data.batchID;
}

void UnpackVisibilityData(uint packedData0, uint packedData1, out VisibilityData data)
{
    data.valid = (packedData0 >> 31) != 0;
    data.DOTSInstanceIndex = (packedData0 & 0xffff);
    data.primitiveID = (packedData0 >> 16) & 0x7fff;
    data.batchID = packedData1;
}

uint GetMaterialKey(in VisibilityData visData, out GeoPoolMetadataEntry metadataEntry)
{
    if (!visData.valid)
    {
        metadataEntry = (GeoPoolMetadataEntry)0;
        return 0;
    }

    metadataEntry = GeometryPool::GetMetadataEntry(visData.DOTSInstanceIndex, visData.batchID);
    return GeometryPool::GetMaterialKey(metadataEntry, visData.primitiveID);
}

VisibilityData LoadVisibilityData(uint2 coord)
{
    uint value0 = LOAD_TEXTURE2D_X(_VisBufferTexture0, (uint2)coord.xy).x;
    uint value1 = LOAD_TEXTURE2D_X(_VisBufferTexture1, (uint2)coord.xy).x;
    VisibilityData visData;
    Visibility::UnpackVisibilityData(value0, value1, visData);
    return visData;
}

uint GetMaterialKey(in VisibilityData visData)
{
    GeoPoolMetadataEntry unused;
    return GetMaterialKey(visData, unused);
}

uint2 GetTileCoord(uint2 coord)
{
    return coord >> VIS_BUFFER_TILE_LOG2;
}

uint LoadFeatureTile(uint2 tileCoord)
{
    return LOAD_TEXTURE2D_X(_VisBufferFeatureTiles, tileCoord).x;
}

uint2 LoadMaterialTile(uint2 tileCoord)
{
    return LOAD_TEXTURE2D_X(_VisBufferMaterialTiles, tileCoord).xy;
}

uint LoadBucketTile(uint2 tileCoord)
{
    return LOAD_TEXTURE2D_X(_VisBufferBucketTiles, tileCoord).x;
}

float PackDepthMaterialKey(uint materialGPUBatchKey)
{
    return float(materialGPUBatchKey & 0xffffff) / (float)0xffffff;
}

}

#endif
