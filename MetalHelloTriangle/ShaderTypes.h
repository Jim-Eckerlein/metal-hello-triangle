#pragma once

#include <simd/simd.h>

#define BufferIndexMeshPositions 0
#define BufferIndexMeshColors 1
#define BufferIndexUniforms 2

#define VertexAttributePosition 0
#define VertexAttributeColor 1

typedef struct
{
    matrix_float4x4 transform;
} Uniforms;
