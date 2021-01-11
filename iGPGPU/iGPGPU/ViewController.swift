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
    
    private let row: Int = 3000
    private let column: Int = 40000
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction private func doSequence(sender: Any) {
        var array = Array(repeating: Array<Double>(repeating: 0, count: self.column), count: self.row)
        let start = DispatchTime.now()
        for i in 0..<row {
            for j in 0..<column{
                array[i][j] = Double(i * j)
            }
        }
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        self.sequenceLabel?.text = "Time to execute: \(timeInterval) seconds"
    }

    @IBAction private func doGCD(sender: Any) {
        let button = sender as? UIButton
        button?.isEnabled = false
        let group = DispatchGroup()
        let saveQueue = DispatchQueue(label: "saveWorker")
        var array = Array(repeating: Array<Double>(repeating: 0, count: self.column), count: self.row)
        
        let start = DispatchTime.now()
        for i in 0..<row {
            group.enter()
            DispatchQueue.global(qos: .userInteractive).async {
                var values = [Double]()
                for j in 0..<self.column{
                    values.append(Double(i * j))
                }
                saveQueue.async {
                    array[i] = values
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
        }
    }
    
    @IBAction private func doGPGPU(sender: Any) {
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue(), let library = device.makeDefaultLibrary(), let commandBuffer = commandQueue.makeCommandBuffer(), let computeEncoder = commandBuffer.makeComputeCommandEncoder(), let computeFunction = library.makeFunction(name: "kernel_main"), let computePipelineState = try? device.makeComputePipelineState(function: computeFunction) else {
            debugPrint("cant use metal")
            return
        }
        var aColumn = self.column
        let aRow = self.row
        var array = Array(repeating: Array<Double>(repeating: 0, count: aColumn), count: aRow)

        let start = DispatchTime.now()
        let matrixBuffer = device.makeBuffer(bytes: &array, length: Int(aRow*aColumn) * MemoryLayout<Float>.stride, options: [])
        computeEncoder.pushDebugGroup("settingup")
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setBuffer(matrixBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&aColumn, length: MemoryLayout<uint>.stride, index: 1)
        let threadsPerThreadGrid = MTLSizeMake(Int(aRow * aColumn), 1, 1)
        computeEncoder.dispatchThreadgroups(threadsPerThreadGrid, threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
        computeEncoder.endEncoding()
        computeEncoder.popDebugGroup()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        self.gpgpuLabel?.text = "Time to execute: \(timeInterval) seconds"
        let contents = matrixBuffer?.contents()
        let pointer = contents?.bindMemory(to: Float.self, capacity: Int(aRow*aColumn))
        print(array.last?.last)
    }
}

