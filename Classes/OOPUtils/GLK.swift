//
//  GLK.swift
//  OOPUtils
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/1/4.
//
//
/*
Copyright (c) 2015, OOPer(NAGATA, Atsuyuki)
All rights reserved.

Use of any parts(functions, classes or any other program language components)
of this file is permitted with no restrictions, unless you
redistribute or use this file in its entirety without modification.
In this case, providing any sort of warranties or not is the user's responsibility.

Redistribution and use in source and/or binary forms, without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import UIKit

struct GLK {
    struct Matrix4 {
        var m: [GLfloat] = Array(count: 4 * 4, repeatedValue: 0)
    }
}

extension GLK.Matrix4 {
    static var Identity = GLK.Matrix4(m: [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    ])
    
    ///https://www.opengl.org/sdk/docs/man2/xhtml/glMultMatrix.xml
    static func Multiply(u: GLK.Matrix4, _ v: GLK.Matrix4) -> GLK.Matrix4 {
        var result = GLK.Matrix4()
        for i in 0..<4 {
            for j in 0..<4 {
                var sum: Float = 0.0
                for k in 0..<4 {
                    sum += u.m[i*4+k] * v.m[k*4+j]
                }
                result.m[i*4+j] = sum
//                result.m[i*4+j] = (0..<4).map{k in u.m[i*4+k] * v.m[k*4+j]}.reduce(0, +)
            }
        }
        return result
    }
    
    ///https://www.opengl.org/sdk/docs/man2/xhtml/glOrtho.xml
    static func MakeOrtho(left: Float, _ right: Float,
        _ bottom: Float, _ top: Float,
        _ nearZ: Float, _ farZ: Float) -> GLK.Matrix4
    {
        let dx = 1/(right - left)
        let dy = 1/(top - bottom)
        let dz = 1/(farZ - nearZ)
        let tx = -(right + left) * dx
        let ty = -(top + bottom) * dy
        let tz = -(farZ + nearZ) * dz
        var result = GLK.Matrix4(m: [
            2 * dx, 0, 0, 0,
            0, 2 * dy, 0, 0,
            0, 0, -2 * dz, 0,
            tx, ty, tz, 1,
            ])
        return result
    }
}