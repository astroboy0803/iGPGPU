//
//  Shaders.metal
//  iGPGPU
//
//  Created by i9400506 on 2021/1/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void kernel_main(device float* factors [[buffer(0)]], constant uint& column [[buffer(1)]], uint pid [[thread_position_in_grid]]){
    factors[pid] = (pid / column) * (pid % column);
}
