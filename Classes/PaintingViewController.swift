//
//  PaintingViewController.swift
//  GLPaint
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/5.
//
//
/*
     File: PaintingViewController.h
     File: PaintingViewController.m
 Abstract: The central controller of the application.
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

//CONSTANTS:

let kBrightness =       1.0
let kSaturation =       0.45

let kPaletteHeight =	30
let kPaletteSize =	5
let kMinEraseInterval =	0.5

// Padding for margins
let kLeftMargin =	10.0
let kTopMargin =	10.0
let kRightMargin =      10.0

//CLASS IMPLEMENTATIONS:

@objc(PaintingViewController)
class PaintingViewController: UIViewController {
    private var erasingSound: SoundEffect!
    private var selectSound: SoundEffect!
    private var lastTime: CFTimeInterval = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a segmented control so that the user can choose the brush color.
        // Create the UIImages with the UIImageRenderingModeAlwaysOriginal rendering mode. This allows us to show the actual image colors in the segmented control.
        let segmentedControl = UISegmentedControl(items: [
            
            UIImage(named: "Red")!.imageWithRenderingMode(.AlwaysOriginal),
            UIImage(named: "Yellow")!.imageWithRenderingMode(.AlwaysOriginal),
            UIImage(named: "Green")!.imageWithRenderingMode(.AlwaysOriginal),
            UIImage(named: "Blue")!.imageWithRenderingMode(.AlwaysOriginal),
            UIImage(named: "Purple")!.imageWithRenderingMode(.AlwaysOriginal),
            ])
        
        // Compute a rectangle that is positioned correctly for the segmented control you'll use as a brush color palette
        let rect = UIScreen.mainScreen().bounds
        let frame = CGRectMake(rect.origin.x + kLeftMargin.g, rect.size.height - kPaletteHeight.g - kTopMargin.g, rect.size.width - (kLeftMargin + kRightMargin).g, kPaletteHeight.g)
        segmentedControl.frame = frame
        // When the user chooses a color, the method changeBrushColor: is called.
        segmentedControl.addTarget(self, action: "changeBrushColor:", forControlEvents: .ValueChanged)
        // Make sure the color of the color complements the black background
        segmentedControl.tintColor = UIColor.darkGrayColor()
        // Set the third color (index values start at 0)
        segmentedControl.selectedSegmentIndex = 2
        
        // Add the control to the window
        self.view.addSubview(segmentedControl)
        // Now that the control is added, you can release it
        
        // Define a starting color
        let color = UIColor(hue: 2.0.g / kPaletteSize.g,
            saturation: kSaturation.g,
            brightness: kBrightness.g,
            alpha: 1.0).CGColor
        let components = CGColorGetComponents(color)
        
        // Defer to the OpenGL view to set the brush color
        (self.view as! PaintingView).setBrushColorWithRed(components[0], green: components[1], blue: components[2])
        
        // Load the sounds
        let mainBundle = NSBundle.mainBundle()
        erasingSound = SoundEffect(contentsOfFile: mainBundle.pathForResource("Erase", ofType: "caf")!)!
        selectSound = SoundEffect(contentsOfFile: mainBundle.pathForResource("Select", ofType: "caf")!)!
        
        // Erase the view when recieving a notification named "shake" from the NSNotificationCenter object
        // The "shake" nofification is posted by the PaintingWindow object when user shakes the device
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "eraseView", name: "shake", object: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.becomeFirstResponder()
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    // Release resources when they are no longer needed,
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // Change the brush color
    func changeBrushColor(sender: AnyObject) {
        // Play sound
        selectSound.play()
        
        // Define a new brush color
        let senderSegment = sender as! UISegmentedControl
        let color = UIColor(hue: senderSegment.selectedSegmentIndex.g / kPaletteSize.g,
            saturation: kSaturation.g,
            brightness: kBrightness.g,
            alpha: 1.0).CGColor
        let components = CGColorGetComponents(color)
        
        // Defer to the OpenGL view to set the brush color
        (self.view as! PaintingView).setBrushColorWithRed(components[0], green: components[1], blue: components[2])
    }
    
    // Called when receiving the "shake" notification; plays the erase sound and redraws the view
    func eraseView() {
        if CFAbsoluteTimeGetCurrent() > lastTime + kMinEraseInterval {
            erasingSound.play()
            (self.view as! PaintingView).erase()
            lastTime = CFAbsoluteTimeGetCurrent()
        }
    }
    
    // We do not support auto-rotation in this sample
    override func shouldAutorotate() -> Bool {
        return false
    }
    
    //MARK: Motion
    
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?) {
        if motion == UIEventSubtype.MotionShake {
            // User was shaking the device. Post a notification named "shake".
            NSNotificationCenter.defaultCenter().postNotificationName("shake", object: self)
        }
    }
    
}