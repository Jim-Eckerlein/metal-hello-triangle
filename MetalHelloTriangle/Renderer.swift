import Metal
import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate {

    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    
    var mtlVertexDescriptor = MTLVertexDescriptor()
    var indexBuffer: MTLBuffer
    var positionBuffer: MTLBuffer
    var colorBuffer: MTLBuffer
    
    var uniforms: UnsafeMutablePointer<Uniforms>

    init?(metalKitView: MTKView) {
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!

        self.dynamicUniformBuffer = self.device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                                           options: [MTLResourceOptions.storageModeShared])!
        self.dynamicUniformBuffer.label = "UniformBuffer"

        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity: 1)

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        
        mtlVertexDescriptor.attributes[VertexAttribute.color.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.color.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.color.rawValue].bufferIndex = BufferIndex.meshColors.rawValue
        
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = MemoryLayout<SIMD3<Float>>.stride
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        mtlVertexDescriptor.layouts[BufferIndex.meshColors.rawValue].stride = MemoryLayout<SIMD3<Float>>.stride
        mtlVertexDescriptor.layouts[BufferIndex.meshColors.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshColors.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }

        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor:depthStateDescriptor)!
        
        let indices: [UInt16] = [0, 1, 2]
        let positions: [SIMD3<Float>] = [.init(-1, -1, 0), .init(1, -1, 0), .init(0, 1, 0)];
        let colors: [SIMD3<Float>] = [.init(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)];
        
        indexBuffer = device.makeBuffer(bytes: indices,
                                        length: MemoryLayout<UInt16>.stride * indices.count,
                                        options: .cpuCacheModeWriteCombined)!
        
        positionBuffer = device.makeBuffer(bytes: positions,
                                           length: MemoryLayout<SIMD3<Float>>.stride * positions.count,
                                           options: .cpuCacheModeWriteCombined)!
        
        colorBuffer = device.makeBuffer(bytes: colors,
                                        length: MemoryLayout<SIMD3<Float>>.stride * colors.count,
                                        options: .cpuCacheModeWriteCombined)!

        super.init()
    }

    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object

        let library = device.makeDefaultLibrary()

        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor

        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat

        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    private func updateUniforms() {
        uniforms[0].transform = .init(diagonal: .init(x: 0.5, y: 0.5, z: 0.5, w: 1))
    }

    func draw(in view: MTKView) {        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            self.updateUniforms()
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor = renderPassDescriptor {
                
                /// Final pass rendering code here
                guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                    return
                }
                
                renderEncoder.label = "Primary Render Encoder"
                renderEncoder.pushDebugGroup("Draw Triangle")
                
                renderEncoder.setCullMode(.back)
                renderEncoder.setFrontFacing(.counterClockwise)
                
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setDepthStencilState(depthState)
                
                renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset: 0, index: BufferIndex.uniforms.rawValue)
                renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset: 0, index: BufferIndex.uniforms.rawValue)
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: BufferIndex.meshPositions.rawValue)
                renderEncoder.setVertexBuffer(colorBuffer, offset: 0, index: BufferIndex.meshColors.rawValue)
                
                renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 3, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
                
                renderEncoder.popDebugGroup()
                renderEncoder.endEncoding()
                
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        //aspect = Float(size.width) / Float(size.height)
    }
}
