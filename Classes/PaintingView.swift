//
//  PaintingView.swift
//  GLPaint
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/4.
//
//
/*
     File: PaintingView.h
     File: PaintingView.m
 Abstract: The class responsible for the finger painting. The class wraps the
 CAEAGLLayer from CoreAnimation into a convenient UIView subclass. The view
 content is basically an EAGL surface you render your OpenGL scene into.
  Version: 1.13

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2014 Apple Inc. All Rights Reserved.

*/

import UIKit
import GLKit

//CONSTANTS:

let kBrushOpacity = (1.0 / 3.0)
let kBrushPixelStep = 3
let kBrushScale = 2


// Shaders
let PROGRAM_POINT = 0

let UNIFORM_MVP = 0
let UNIFORM_POINT_SIZE = 1
let UNIFORM_VERTEX_COLOR = 2
let UNIFORM_TEXTURE = 3
let NUM_UNIFORMS = 4

let ATTRIB_VERTEX = 0
let NUM_ATTRIBS = 1

typealias programInfo_t = (
    vert: String, frag: String,
    uniform: [GLint],
    id: GLuint)

var program: [programInfo_t] = [
    ("point.vsh",   "point.fsh", Array(repeating: 0, count: NUM_UNIFORMS), 0),     // PROGRAM_POINT
]
let NUM_PROGRAMS = program.count


// Texture
typealias textureInfo_t = (
    id: GLuint,
    width: GLsizei, height: GLsizei)


@objc(PaintingView)
class PaintingView: UIView {
    // The pixel dimensions of the backbuffer
    private var backingWidth: GLint = 0
    private var backingHeight: GLint = 0
    
    private var context: EAGLContext!
    
    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    private var viewRenderbuffer: GLuint = 0, viewFramebuffer: GLuint = 0
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    private var depthRenderbuffer: GLuint = 0
    
    private var brushTexture: textureInfo_t = (0, 0, 0)     // brush texture
    private var brushColor: [GLfloat] = [0, 0, 0, 0]          // brush color
    
    private var firstTouch: Bool = false
    private var needsErase: Bool = false
    
    // Shader objects
    private var vertexShader: GLuint = 0
    private var fragmentShader: GLuint = 0
    private var shaderProgram: GLuint = 0
    
    // Buffer Objects
    private var vboId: GLuint = 0
    
    private var initialized: Bool = false
    
    var location: CGPoint = CGPoint()
    var previousLocation: CGPoint = CGPoint()
    
    // Implement this to override the default layer class (which is [CALayer class]).
    // We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
    override class var layerClass : AnyClass {
        return CAEAGLLayer.self
    }
    
    // The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
    required init?(coder: NSCoder) {
        
        super.init(coder: coder)
        let eaglLayer = self.layer as! CAEAGLLayer
        
        eaglLayer.isOpaque = true
        // In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.
        eaglLayer.drawableProperties = [
            kEAGLDrawablePropertyRetainedBacking: true,
            kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
        ]
        
        context = EAGLContext(api: .openGLES2)
        
        if context == nil || !EAGLContext.setCurrent(context) {
            fatalError("EAGLContext cannot be created")
        }
        
        // Set the view's scale factor as you wish
        self.contentScaleFactor = UIScreen.main.scale
        
        // Make sure to start with a cleared buffer
        needsErase = true
        
    }
    
    // If our view is resized, we'll be asked to layout subviews.
    // This is the perfect opportunity to also update the framebuffer so that it is
    // the same size as our display area.
    override func layoutSubviews() {
        EAGLContext.setCurrent(context)
        
        if !initialized {
            initialized = self.initGL()
        } else {
            self.resize(from: self.layer as! CAEAGLLayer)
        }
        
        // Clear the framebuffer the first time it is allocated
        if needsErase {
            self.erase()
            needsErase = false
        }
    }
    
    private func setupShaders() {
        for i in 0..<NUM_PROGRAMS {
            let vsrc = readData(forResource: program[i].vert)
            let fsrc = readData(forResource: program[i].frag)
            var attribUsed: [String] = []
            var attrib: [GLuint] = []
            let attribName: [String] = [
                "inVertex",
                ]
            let uniformName: [String] = [
                "MVP", "pointSize", "vertexColor", "texture",
                ]
            
            var prog: GLuint = 0
            vsrc.withUnsafeBytes {vsrcBytes in
                let vsrcChars = vsrcBytes.bindMemory(to: GLchar.self).baseAddress!
                
                // auto-assign known attribs
                for (j, name) in attribName.enumerated() {
                    if strstr(vsrcChars, name) != nil {
                        attrib.append(j.ui)
                        attribUsed.append(name)
                    }
                }
                
                fsrc.withUnsafeBytes {fsrcBytes in
                    let fsrcChars = fsrcBytes.bindMemory(to: GLchar.self).baseAddress!
                    _ = glue.createProgram(UnsafeMutablePointer(mutating: vsrcChars), UnsafeMutablePointer(mutating: fsrcChars),
                                           attribUsed, attrib,
                                           uniformName, &program[i].uniform,
                                           &prog)
                }
            }
            program[i].id = prog
            
            // Set constant/initalize uniforms
            if i == PROGRAM_POINT {
                glUseProgram(program[PROGRAM_POINT].id)
                
                // the brush texture will be bound to texture unit 0
                glUniform1i(program[PROGRAM_POINT].uniform[UNIFORM_TEXTURE], 0)
                
                // viewing matrices
                let projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth.f, 0, backingHeight.f, -1, 1)
                let modelViewMatrix = GLKMatrix4Identity
                var MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
                
                withUnsafePointer(to: &MVPMatrix) {ptrMVP in
                    ptrMVP.withMemoryRebound(to: GLfloat.self, capacity: 16) {ptrGLfloat in
                        glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE.ub, ptrGLfloat)
                    }
                }
                
                // point size
                glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_POINT_SIZE], brushTexture.width.f / kBrushScale.f)
                
                // initialize brush color
                glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor)
            }
        }
        
        glError()
    }
    
    // Create a texture from an image
    private func texture(fromName name: String) -> textureInfo_t {
        var texId: GLuint = 0
        var texture: textureInfo_t = (0, 0, 0)
        
        // First create a UIImage object from the data in a image file, and then extract the Core Graphics image
        let brushImage = UIImage(named: name)?.cgImage
        
        // Get the width and height of the image
        let width: size_t = brushImage!.width
        let height: size_t = brushImage!.height
        
        // Make sure the image exists
        if brushImage != nil {
            // Allocate  memory needed for the bitmap context
            var brushData = [GLubyte](repeating: 0, count: width * height * 4)
            // Use  the bitmatp creation function provided by the Core Graphics framework.
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            let brushContext = CGContext(data: &brushData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: (brushImage?.colorSpace!)!, bitmapInfo: bitmapInfo)
            // After you create the context, you can draw the  image to the context.
            brushContext?.draw(brushImage!, in: CGRect(x: 0.0, y: 0.0, width: width.g, height: height.g))
            // You don't need the context at this point, so you need to release it to avoid memory leaks.
            // Use OpenGL ES to generate a name for the texture.
            glGenTextures(1, &texId)
            // Bind the texture name.
            glBindTexture(GL_TEXTURE_2D.ui, texId)
            // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
            glTexParameteri(GL_TEXTURE_2D.ui, GL_TEXTURE_MIN_FILTER.ui, GL_LINEAR)
            // Specify a 2D texture image, providing the a pointer to the image data in memory
            glTexImage2D(GL_TEXTURE_2D.ui, 0, GL_RGBA, width.i, height.i, 0, GL_RGBA.ui, GL_UNSIGNED_BYTE.ui, brushData)
            // Release  the image data; it's no longer needed
            
            texture.id = texId
            texture.width = width.i
            texture.height = height.i
        }
        
        return texture
    }
    
    private func initGL() -> Bool {
        // Generate IDs for a framebuffer object and a color renderbuffer
        glGenFramebuffers(1, &viewFramebuffer)
        glGenRenderbuffers(1, &viewRenderbuffer)
        
        glBindFramebuffer(GL_FRAMEBUFFER.ui, viewFramebuffer)
        glBindRenderbuffer(GL_RENDERBUFFER.ui, viewRenderbuffer)
        // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
        // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
        context.renderbufferStorage(GL_RENDERBUFFER.l, from: (self.layer as! EAGLDrawable))
        glFramebufferRenderbuffer(GL_FRAMEBUFFER.ui, GL_COLOR_ATTACHMENT0.ui, GL_RENDERBUFFER.ui, viewRenderbuffer)
        
        glGetRenderbufferParameteriv(GL_RENDERBUFFER.ui, GL_RENDERBUFFER_WIDTH.ui, &backingWidth)
        glGetRenderbufferParameteriv(GL_RENDERBUFFER.ui, GL_RENDERBUFFER_HEIGHT.ui, &backingHeight)
        
        // For this sample, we do not need a depth buffer. If you do, this is how you can create one and attach it to the framebuffer:
        //    glGenRenderbuffers(1, &depthRenderbuffer);
        //    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
        //    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
        //    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
        
        if glCheckFramebufferStatus(GL_FRAMEBUFFER.ui) != GL_FRAMEBUFFER_COMPLETE.ui {
            NSLog("failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER.ui))
            return false
        }
        
        // Setup the view port in Pixels
        glViewport(0, 0, backingWidth, backingHeight)
        
        // Create a Vertex Buffer Object to hold our data
        glGenBuffers(1, &vboId)
        
        // Load the brush texture
        brushTexture = self.texture(fromName: "Particle.png")
        
        // Load shaders
        self.setupShaders()
        
        // Enable blending and set a blending function appropriate for premultiplied alpha pixel data
        glEnable(GL_BLEND.ui)
        glBlendFunc(GL_ONE.ui, GL_ONE_MINUS_SRC_ALPHA.ui)
        
        // Playback recorded path, which is "Shake Me"
        let recordedPaths = NSArray(contentsOfFile: Bundle.main.path(forResource: "Recording", ofType: "data")!)! as! [Data]
        if recordedPaths.count != 0 {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 200 * NSEC_PER_MSEC.d / NSEC_PER_SEC.d) {
                self.playback(recordedPaths, fromIndex: 0)
            }
        }
        
        return true
    }
    
    @discardableResult
    private func resize(from layer: CAEAGLLayer) -> Bool {
        // Allocate color buffer backing based on the current layer size
        glBindRenderbuffer(GL_RENDERBUFFER.ui, viewRenderbuffer)
        context.renderbufferStorage(GL_RENDERBUFFER.l, from: layer)
        glGetRenderbufferParameteriv(GL_RENDERBUFFER.ui, GL_RENDERBUFFER_WIDTH.ui, &backingWidth)
        glGetRenderbufferParameteriv(GL_RENDERBUFFER.ui, GL_RENDERBUFFER_HEIGHT.ui, &backingHeight)
        
        // For this sample, we do not need a depth buffer. If you do, this is how you can allocate depth buffer backing:
        //    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
        //    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
        //    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
        
        if glCheckFramebufferStatus(GL_FRAMEBUFFER.ui) != GL_FRAMEBUFFER_COMPLETE.ui {
            NSLog("Failed to make complete framebuffer objectz %x", glCheckFramebufferStatus(GL_FRAMEBUFFER.ui))
            return false
        }
        
        // Update projection matrix
        let projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth.f, 0, backingHeight.f, -1, 1)
        let modelViewMatrix = GLKMatrix4Identity // this sample uses a constant identity modelView matrix
        var MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
        
        glUseProgram(program[PROGRAM_POINT].id)
        withUnsafePointer(to: &MVPMatrix) {ptrMVP in
            ptrMVP.withMemoryRebound(to: GLfloat.self, capacity: 16) {ptrGLfloat in
                glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE.ub, ptrGLfloat)
            }
        }
        
        // Update viewport
        glViewport(0, 0, backingWidth, backingHeight)
        
        return true
    }
    
    // Releases resources when they are not longer needed.
    deinit {
        // Destroy framebuffers and renderbuffers
        if viewFramebuffer != 0 {
            glDeleteFramebuffers(1, &viewFramebuffer)
        }
        if viewRenderbuffer != 0 {
            glDeleteRenderbuffers(1, &viewRenderbuffer)
        }
        if depthRenderbuffer != 0 {
            glDeleteRenderbuffers(1, &depthRenderbuffer)
        }
        // texture
        if brushTexture.id != 0 {
            glDeleteTextures(1, &brushTexture.id)
        }
        // vbo
        if vboId != 0 {
            glDeleteBuffers(1, &vboId)
        }
        
        // tear down context
        if EAGLContext.current() === context {
            EAGLContext.setCurrent(context)
        }
    }
    
    // Erases the screen
    func erase() {
        EAGLContext.setCurrent(context)
        
        // Clear the buffer
        glBindFramebuffer(GL_FRAMEBUFFER.ui, viewFramebuffer)
        glClearColor(0.0, 0.0, 0.0, 0.0)
        glClear(GL_COLOR_BUFFER_BIT.ui)
        
        // Display the buffer
        glBindRenderbuffer(GL_RENDERBUFFER.ui, viewRenderbuffer)
        context.presentRenderbuffer(GL_RENDERBUFFER.l)
    }
    
    // Drawings a line onscreen based on where the user touches
    private func renderLine(from _start: CGPoint, to _end: CGPoint) {
        struct Static {
            static var vertexBuffer: [GLfloat] = []
        }
        var count = 0
        
        EAGLContext.setCurrent(context)
        glBindFramebuffer(GL_FRAMEBUFFER.ui, viewFramebuffer)
        
        // Convert locations from Points to Pixels
        let scale = self.contentScaleFactor
        var start = _start
        start.x *= scale
        start.y *= scale
        var end = _end
        end.x *= scale
        end.y *= scale
        
        // Allocate vertex array buffer
        
        // Add points to the buffer so there are drawing points every X pixels
        count = max(Int(ceilf(sqrtf((end.x - start.x).f * (end.x - start.x).f + (end.y - start.y).f * (end.y - start.y).f) / kBrushPixelStep.f)), 1)
        Static.vertexBuffer.reserveCapacity(count * 2)
        Static.vertexBuffer.removeAll(keepingCapacity: true)
        for i in 0..<count {
            
            Static.vertexBuffer.append(start.x.f + (end.x - start.x).f * (i.f / count.f))
            Static.vertexBuffer.append(start.y.f + (end.y - start.y).f * (i.f / count.f))
        }
        
        // Load data to the Vertex Buffer Object
        glBindBuffer(GL_ARRAY_BUFFER.ui, vboId)
        glBufferData(GL_ARRAY_BUFFER.ui, count*2*MemoryLayout<GLfloat>.size, Static.vertexBuffer, GL_DYNAMIC_DRAW.ui)
        
        glEnableVertexAttribArray(ATTRIB_VERTEX.ui)
        glVertexAttribPointer(ATTRIB_VERTEX.ui, 2, GL_FLOAT.ui, GL_FALSE.ub, 0, nil)
        
        // Draw
        glUseProgram(program[PROGRAM_POINT].id)
        glDrawArrays(GL_POINTS.ui, 0, count.i)
        
        // Display the buffer
        glBindRenderbuffer(GL_RENDERBUFFER.ui, viewRenderbuffer)
        context.presentRenderbuffer(GL_RENDERBUFFER.l)
    }
    
    // Reads previously recorded points and draws them onscreen. This is the Shake Me message that appears when the application launches.
    
    private func playback(_ recordedPaths: [Data], fromIndex index: Int) {
        // NOTE: Recording.data is stored with 32-bit floats
        // To make it work on both 32-bit and 64-bit devices, we make sure we read back 32 bits each time.
        
        let data = recordedPaths[index]
        let count = data.count / (MemoryLayout<Float32>.size*2) // each point contains 64 bits (32-bit x and 32-bit y)
        
        // Render the current path
        data.withUnsafeBytes { bytes in
            let floats = bytes.bindMemory(to: Float32.self).baseAddress!
            for i in 0..<count - 1 {
                
                var x = floats[2*i]
                var y = floats[2*i+1]
                let point1 = CGPoint(x: x.g, y: y.g)
                
                x = floats[2*(i+1)]
                y = floats[2*(i+1)+1]
                let point2 = CGPoint(x: x.g, y: y.g)
                
                self.renderLine(from: point1, to: point2)
            }
        }
        
        // Render the next path after a short delay
        if recordedPaths.count > index+1 {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 10 * NSEC_PER_MSEC.d / NSEC_PER_SEC.d) {
                self.playback(recordedPaths, fromIndex: index+1)
            }
        }
    }
    
    
    // Handles the start of a touch
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let bounds = self.bounds
        let touch = event!.touches(for: self)!.first!
        firstTouch = true
        // Convert touch point from UIView referential to OpenGL one (upside-down flip)
        location = touch.location(in: self)
        location.y = bounds.size.height - location.y
    }
    
    // Handles the continuation of a touch.
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let bounds = self.bounds
        let touch = event!.touches(for: self)!.first!
        
        // Convert touch point from UIView referential to OpenGL one (upside-down flip)
        if firstTouch {
            firstTouch = false
            previousLocation = touch.previousLocation(in: self)
            previousLocation.y = bounds.size.height - previousLocation.y
        } else {
            location = touch.location(in: self)
            location.y = bounds.size.height - location.y
            previousLocation = touch.previousLocation(in: self)
            previousLocation.y = bounds.size.height - previousLocation.y
        }
        
        // Render the stroke
        self.renderLine(from: previousLocation, to: location)
    }
    
    // Handles the end of a touch event when the touch is a tap.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let bounds = self.bounds
        let touch = event!.touches(for: self)!.first!
        if firstTouch {
            firstTouch = false
            previousLocation = touch.previousLocation(in: self)
            previousLocation.y = bounds.size.height - previousLocation.y
            self.renderLine(from: previousLocation, to: location)
        }
    }
    
    // Handles the end of a touch event.
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // If appropriate, add code necessary to save the state of the application.
        // This application is not saving state.
    }
    
    func setBrushColor(red: CGFloat, green: CGFloat, blue: CGFloat) {
        // Update the brush color
        brushColor[0] = red.f * kBrushOpacity.f
        brushColor[1] = green.f * kBrushOpacity.f
        brushColor[2] = blue.f * kBrushOpacity.f
        brushColor[3] = kBrushOpacity.f
        
        if initialized {
            glUseProgram(program[PROGRAM_POINT].id)
            glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor)
        }
    }
    
    
    override var canBecomeFirstResponder : Bool {
        return true
    }
    
}
