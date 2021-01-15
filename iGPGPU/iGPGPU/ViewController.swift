//
//  ViewController.swift
//  iGPGPU
//
//  Created by i9400506 on 2021/1/11.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet private weak var sequenceLabel: UILabel?
    
    @IBOutlet private weak var gcdLabel: UILabel?
    
    @IBOutlet private weak var gpgpuLabel: UILabel?
    
    private let row: Int = 30001
    private let column: Int = 4001
    
    private var array = [[Double]]()
    
    private var gpAry = [Float]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    @IBAction private func doRelease(sender: Any) {
        self.array.removeAll()
        self.gpAry.removeAll()
        print(self.array.count)
        print(self.gpAry.count)
    }
    
    @IBAction private func doSequence(sender: Any) {
        self.array.removeAll()
        let start = DispatchTime.now()
        for i in 0..<row {
            var ary = [Double]()
            for j in 0..<column {
                ary.append(Double(i * j))
            }
            self.array.append(ary)
        }
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        self.sequenceLabel?.text = "Time to execute: \(timeInterval) seconds"
        print(self.array.last?.last ?? .zero)
    }

    @IBAction private func doGCD(sender: Any) {
        self.array.removeAll()
        self.array = [[Double]].init(repeating: [Double](), count: self.row)
        let button = sender as? UIButton
        button?.isEnabled = false
        let group = DispatchGroup()
        let saveQueue = DispatchQueue(label: "saveWorker")
        
        let start = DispatchTime.now()
        for i in 0..<row {
            group.enter()
            DispatchQueue.global(qos: .userInteractive).async {
                var values = [Double]()
                for j in 0..<self.column{
                    values.append(Double(i * j))
                }
                saveQueue.async {
                    self.array[i] = values
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            let end = DispatchTime.now()
            let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
            let timeInterval = Double(nanoTime) / 1_000_000_000
            self.gcdLabel?.text = "Time to execute: \(timeInterval) seconds"
            button?.isEnabled = true
            print(self.array.last?.last ?? .zero)
        }
    }
    
    @IBAction private func doGPGPU(sender: Any) {
//        if self.gpAry.count > 0 {
//            for idx in (self.column + 1)..<self.gpAry.count {
//                if self.gpAry[idx] != 0 {
//                    print("idx(\(idx)) = \(self.gpAry[idx])")
//                }
//            }
//        }
        
        self.gpAry.removeAll()
        
        let start = DispatchTime.now()
        
        // initial
        let device = MTLCreateSystemDefaultDevice()!
        let library = device.makeDefaultLibrary()!
        let computeFunction = library.makeFunction(name: "multiply")!
        let computePipelineState = try! device.makeComputePipelineState(function: computeFunction)
        let commandQueue = device.makeCommandQueue()!
        
        let times = self.row * self.column
        
        // prepare data - create buffer
        let rowBuffer = device.makeBuffer(length: self.row * MemoryLayout<Float>.stride, options: .storageModeShared)
        let columnBuffer = device.makeBuffer(length: self.column * MemoryLayout<Float>.stride, options: .storageModeShared)
        let resultBuffer = device.makeBuffer(length: times * MemoryLayout<Float>.stride, options: .storageModeShared)
        let lengthBuffer = device.makeBuffer(length: times * MemoryLayout<UInt>.stride, options: .storageModeShared)
        self.generateData(buffer: rowBuffer, count: self.row)
        self.generateData(buffer: columnBuffer, count: self.column)
        self.generateData(buffer: lengthBuffer, count: 1, value: self.column)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setBuffer(rowBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(columnBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(lengthBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(resultBuffer, offset: 0, index: 3)
        
        // Calculate a threadgroup size.
        var threadGroupSize = computePipelineState.maxTotalThreadsPerThreadgroup
        if threadGroupSize > times {
            threadGroupSize = times
        }
        var gSize = times / threadGroupSize
        if times % threadGroupSize != .zero {
            gSize += 1
        }
        let gridSize = MTLSizeMake(gSize, 1, 1)
        let threadsPerThreadGrid = MTLSizeMake(threadGroupSize, 1, 1)
        computeEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadsPerThreadGrid)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        if let rawPointer = resultBuffer?.contents() {
            let pointer = rawPointer.bindMemory(to: Float.self, capacity: times)
            let bufferPointer = UnsafeBufferPointer(start: pointer, count: times)
            self.gpAry = [Float](bufferPointer)
        }
        
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        
        self.gpgpuLabel?.text = "Time to execute: \(timeInterval) seconds"
        let value = self.gpAry.last ?? -1
        print(value)
    }
    
    private final func generateData(buffer: MTLBuffer?, count: Int) {
        guard let buffer = buffer else {
            return
        }
        var pointer = buffer.contents()
        for idx in 0..<count {
            pointer.storeBytes(of: Float(idx), as: Float.self)
            pointer += MemoryLayout<Float>.stride
        }
        
        // verify
        //self.verify(buffer: buffer, count: count)
    }
    
    private final func generateData(buffer: MTLBuffer?, count: Int, value: Int) {
        guard let buffer = buffer else {
            return
        }
        let info = UInt(value)
        var pointer = buffer.contents()
        for _ in 0..<count {
            pointer.storeBytes(of: info, as: UInt.self)
            pointer += MemoryLayout<UInt>.stride
        }
        
        // verify
        //self.verify(buffer: buffer, count: count)
    }
    
    private final func verify(buffer: MTLBuffer?, count: Int) {
        guard let buffer = buffer else {
            return
        }
        var vPointer = buffer.contents()
        
        // print last
        vPointer += MemoryLayout<Float>.stride * (count - 1)
        let value = vPointer.load(as: Float.self)
        print(value)
        
//        let start = count / 2
//        let end = count + self.column
//        for idx in start..<end {
//            let value = vPointer.load(as: Float.self)
//            print("index(\(idx)) = \(value)")
//            vPointer += MemoryLayout<Float>.stride
//        }
    }
}

