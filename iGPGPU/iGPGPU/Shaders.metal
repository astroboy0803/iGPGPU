//
//  Shaders.metal
//  iGPGPU
//
//  Created by i9400506 on 2021/1/11.
//
#include <metal_stdlib>
using namespace metal;

kernel void multiply(device const float* inA, device const float* inB, device const uint* inC, device float* result, uint index [[thread_position_in_grid]]) {
    result[index] = inA[index / inC[0]] * inB[index % inC[0]];
}
