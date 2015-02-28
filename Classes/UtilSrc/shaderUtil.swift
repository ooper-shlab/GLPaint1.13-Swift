//
//  shaderUtil.swift
//  GLPaint
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/4.
//
//
/*
     File: shaderUtil.h
     File: shaderUtil.c
 Abstract: Functions that compile, link and validate shader programs.
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
import OpenGLES


private func printf(format: String, args: [CVarArgType]) {
    print(String(format: format, arguments: args))
}
private func printf(format: String, args: CVarArgType...) {
    printf(format, args)
}
func LogInfo(format: String, args: CVarArgType...) {
    printf(format, args)
}
func LogError(format: String, args: CVarArgType...) {
    printf(format, args)
}


struct glue {
    
    /* Shader Utilities */
    
    /* Compile a shader from the provided source(s) */
    static func compileShader(target: GLenum,
        _ count: GLsizei,
        _ sources: UnsafePointer<UnsafePointer<CChar>>,
        inout _ shader: GLuint) -> GLint
    {
        var logLength: GLint = 0, status: GLint = 0
        
        shader = glCreateShader(target)
        glShaderSource(shader, count, sources, nil)
        glCompileShader(shader)
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH.ui, &logLength)
        if logLength > 0 {
            let log = UnsafeMutablePointer<CChar>.alloc(logLength.l)
            glGetShaderInfoLog(shader, logLength, &logLength, log)
            LogInfo("Shader compile log:\n%@", String.fromCString(log)!)
            log.dealloc(logLength.l)
        }
        
        glGetShaderiv(shader, GL_COMPILE_STATUS.ui, &status)
        if status == 0 {
            
            LogError("Failed to compile shader:\n")
            for i in 0..<count.l {
                LogInfo("%@", String.fromCString(sources[i])!)
            }
        }
        glError()
        
        return status
    }
    
    
    /* Link a program with all currently attached shaders */
    static func linkProgram(program: GLuint) -> GLint {
        var logLength: GLint = 0, status: GLint = 0
        
        glLinkProgram(program)
        glGetProgramiv(program, GL_INFO_LOG_LENGTH.ui, &logLength)
        if logLength > 0 {
            let log = UnsafeMutablePointer<CChar>.alloc(logLength.l)
            glGetProgramInfoLog(program, logLength, &logLength, log)
            LogInfo("Program link log:\n%@", String.fromCString(log)!)
            log.dealloc(logLength.l)
        }
        
        glGetProgramiv(program, GL_LINK_STATUS.ui, &status)
        if status == 0 {
            LogError("Failed to link program %d", program)
        }
        glError()
        
        return status
    }
    
    
    /* Validate a program (for i.e. inconsistent samplers) */
    static func validateProgram(program: GLuint) -> GLint {
        var logLength: GLint = 0, status: GLint = 0
        
        glValidateProgram(program)
        glGetProgramiv(program, GL_INFO_LOG_LENGTH.ui, &logLength)
        if logLength > 0 {
            let log = UnsafeMutablePointer<CChar>.alloc(logLength.l)
            glGetProgramInfoLog(program, logLength, &logLength, log)
            LogInfo("Program validate log:\n%@", String.fromCString(log)!)
            log.dealloc(logLength.l)
        }
        
        glGetProgramiv(program, GL_VALIDATE_STATUS.ui, &status)
        if status == 0 {
            LogError("Failed to validate program %d", program)
        }
        glError()
        
        return status
    }
    
    
    /* Return named uniform location after linking */
    static func getUniformLocation(program: GLuint, _ uniformName: UnsafePointer<CChar>) -> GLint {
        
        return glGetUniformLocation(program, uniformName)
        
    }
    
    
    /* Shader Conveniences */
    
    /* Convenience wrapper that compiles, links, enumerates uniforms and attribs */
    static func createProgram(var vertSource: UnsafePointer<CChar>,
        var _ fragSource: UnsafePointer<CChar>,
        _ attribNames: [String],
        _ attribLocations: [GLuint],
        _ uniformNames: [String],
        inout _ uniformLocations: [GLint],
        inout _ program: GLuint) -> GLint
    {
        var vertShader: GLuint = 0, fragShader: GLuint = 0, prog: GLuint = 0, status: GLint = 1
        
        prog = glCreateProgram()
        
        status *= compileShader(GL_VERTEX_SHADER.ui, 1, &vertSource, &vertShader)
        status *= compileShader(GL_FRAGMENT_SHADER.ui, 1, &fragSource, &fragShader)
        glAttachShader(prog, vertShader)
        glAttachShader(prog, fragShader)
        
        for i in 0..<attribNames.count {
            if !attribNames[i].isEmpty {
                glBindAttribLocation(prog, attribLocations[i], attribNames[i])
            }
        }
        
        status *= linkProgram(prog)
        status *= validateProgram(prog)
        
        if status != 0 {
            for i in 0..<uniformNames.count {
                if !uniformNames[i].isEmpty {
                    uniformLocations[i] = getUniformLocation(prog, uniformNames[i])
                }
            }
            program = prog
        }
        if vertShader != 0 {
            glDeleteShader(vertShader)
        }
        if fragShader != 0 {
            glDeleteShader(fragShader)
        }
        glError()
        
        return status
    }
}