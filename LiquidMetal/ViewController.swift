//
//  ViewController.swift
//  LiquidMetal
//
//  Created by Allen Tan on 11/16/14.
//  Copyright (c) 2014 White Widget Limited. All rights reserved.
//

import UIKit
import CoreMotion
import QuartzCore
import Metal

class ViewController: UIViewController {

  let gravity: Float = 9.80665
  let ptmRatio: Float = 32.0
  let particleRadius: Float = 9
  var particleSystem: UnsafeMutablePointer<Void>!
  var device: MTLDevice! = nil
  var metalLayer: CAMetalLayer! = nil
  var particleCount: Int = 0
  var vertexBuffer: MTLBuffer! = nil
  var uniformBuffer: MTLBuffer! = nil
  // add these properties below var uniformBuffer: MTLBuffer! = nil
  var pipelineState: MTLRenderPipelineState! = nil
  var commandQueue: MTLCommandQueue! = nil
  let motionManager: CMMotionManager = CMMotionManager()
  
  deinit {
    LiquidFun.destroyWorld()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    
    LiquidFun.createWorldWithGravity(Vector2D(x: 0, y: -gravity))
    
    // add the following after LiquidFun.createWorldWithGravity
    particleSystem = LiquidFun.createParticleSystemWithRadius(particleRadius / ptmRatio, dampingStrength: 0.2, gravityScale: 1, density: 1.2)
    LiquidFun.setParticleLimitForSystem(particleSystem, maxParticles: 1500)
    
    let screenSize: CGSize = UIScreen.mainScreen().bounds.size
    let screenWidth = Float(screenSize.width)
    let screenHeight = Float(screenSize.height)
    
    LiquidFun.createParticleBoxForSystem(particleSystem, position: Vector2D(x: screenWidth * 0.5 / ptmRatio, y: screenHeight * 0.5 / ptmRatio), size: Size2D(width: 50 / ptmRatio, height: 50 / ptmRatio))

    LiquidFun.createEdgeBoxWithOrigin(Vector2D(x: 0, y: 0), size: Size2D(width: screenWidth / ptmRatio, height: screenHeight / ptmRatio))
    
    createMetalLayer()
    refreshVertexBuffer()
    refreshUniformBuffer()
    buildRenderPipeline()
    // add this to viewDidLoad, below buildRenderPipeline()
    //render()
    
    let displayLink = CADisplayLink(target: self, selector: #selector(ViewController.update(_:)))
    displayLink.frameInterval = 1
    displayLink.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
    
    motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue(), withHandler: { (accelerometerData, error) -> Void in
      let acceleration = accelerometerData!.acceleration
      let gravityX = self.gravity * Float(acceleration.x)
      let gravityY = self.gravity * Float(acceleration.y)
      LiquidFun.setGravity(Vector2D(x: gravityX, y: gravityY))
    })
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // add this method inside the class declaration
  func printParticleInfo() {
    let count = Int(LiquidFun.particleCountForSystem(particleSystem))
    print("There are \(count) particles present")
    
    let positions = UnsafePointer<Vector2D>(LiquidFun.particlePositionsForSystem(particleSystem))
    
    for i in 0..<count {
      let position = positions[i]
      print("particle: \(i) position: (\(position.x), \(position.y))")
    }
  }

  func createMetalLayer() {
    // store a reference to the default metal device
    // (the root object of the Metal API, and source of all the other objects)
    device = MTLCreateSystemDefaultDevice()
    
    // create a view
    metalLayer = CAMetalLayer()
    metalLayer.device = device
    metalLayer.pixelFormat = .BGRA8Unorm
    metalLayer.framebufferOnly = true
    metalLayer.frame = view.layer.frame
    view.layer.addSublayer(metalLayer)
  }
  
  func refreshVertexBuffer () {
    particleCount = Int(LiquidFun.particleCountForSystem(particleSystem))
    let positions = LiquidFun.particlePositionsForSystem(particleSystem)
    let bufferSize = sizeof(Float) * particleCount * 2
    vertexBuffer = device.newBufferWithBytes(positions, length: bufferSize, options: MTLResourceOptions.CPUCacheModeDefaultCache)
  }
  
  func refreshUniformBuffer () {
    // 1
    let screenSize: CGSize = UIScreen.mainScreen().bounds.size
    let screenWidth = Float(screenSize.width)
    let screenHeight = Float(screenSize.height)
    let ndcMatrix = makeOrthographicMatrix(0, right: screenWidth,
      bottom: 0, top: screenHeight,
      near: -1, far: 1)
    var radius = particleRadius
    var ratio = ptmRatio
    
    // 2
    let floatSize = sizeof(Float)
    let float4x4ByteAlignment = floatSize * 4
    let float4x4Size = floatSize * 16
    let paddingBytesSize = float4x4ByteAlignment - floatSize * 2
    let uniformsStructSize = float4x4Size + floatSize * 2 + paddingBytesSize
    
    // 3
    uniformBuffer = device.newBufferWithLength(uniformsStructSize, options: MTLResourceOptions.CPUCacheModeDefaultCache)
    let bufferPointer = uniformBuffer.contents()
    memcpy(bufferPointer, ndcMatrix, float4x4Size)
    memcpy(bufferPointer + float4x4Size, &ratio, floatSize)
    memcpy(bufferPointer + float4x4Size + floatSize, &radius, floatSize)
  }
  
  func makeOrthographicMatrix(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> [Float] {
    let ral = right + left
    let rsl = right - left
    let tab = top + bottom
    let tsb = top - bottom
    let fan = far + near
    let fsn = far - near
    
    return [2.0 / rsl, 0.0, 0.0, 0.0,
      0.0, 2.0 / tsb, 0.0, 0.0,
      0.0, 0.0, -2.0 / fsn, 0.0,
      -ral / rsl, -tab / tsb, -fan / fsn, 1.0]
  }
  
  func buildRenderPipeline() {
    // create render pipeline
    let defaultLibrary = device.newDefaultLibrary()
    let fragmentProgram = defaultLibrary?.newFunctionWithName("basic_fragment")
    let vertexProgram = defaultLibrary?.newFunctionWithName("particle_vertex")
    
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexProgram
    pipelineDescriptor.fragmentFunction = fragmentProgram
    pipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm

    device.newRenderPipelineStateWithDescriptor(pipelineDescriptor, completionHandler: foo)
  }

  func foo(state: MTLRenderPipelineState?, error: NSError?) -> Void {
    if error != nil {
      print("Error occurred when creating render pipelinate: \(error)");
    }
    pipelineState = state
    commandQueue = device.newCommandQueue()
    render()

  }

  // add this method
  func render() {
    var drawable = metalLayer.nextDrawable()
    
    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = drawable!.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .Clear
    renderPassDescriptor.colorAttachments[0].storeAction = .Store
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 104.0/255.0, blue: 5.0/255.0, alpha: 1.0)
    
    let commandBuffer = commandQueue.commandBuffer()
    
    let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
    renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
    
    renderEncoder.drawPrimitives(.Point, vertexStart: 0, vertexCount: particleCount, instanceCount:1)
    renderEncoder.endEncoding()
    
    commandBuffer.presentDrawable(drawable!)
    commandBuffer.commit()
  }
  
  func update(displayLink:CADisplayLink) {
    autoreleasepool {
      LiquidFun.worldStep(displayLink.duration, velocityIterations: 8, positionIterations: 3)
      self.refreshVertexBuffer()
      self.render()
    }
  }
  
override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
  for touchObject in touches {
    if let touch = touchObject as? UITouch {
      let touchLocation = touch.locationInView(view)
      let position = Vector2D(x: Float(touchLocation.x) / ptmRatio,
        y: Float(view.bounds.height - touchLocation.y) / ptmRatio)
      let size = Size2D(width: 100 / ptmRatio, height: 100 / ptmRatio)
      LiquidFun.createParticleBoxForSystem(particleSystem, position: position, size: size)
    }
  }
}
}

