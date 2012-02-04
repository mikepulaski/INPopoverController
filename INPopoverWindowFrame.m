//
//  INPopoverWindowFrame.m
//  Copyright 2011 Indragie Karunaratne. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "INPopoverWindowFrame.h"
#import <CoreServices/CoreServices.h>
#import <QuartzCore/QuartzCore.h>

@interface INPopoverWindowFrame ()
- (NSBezierPath*)_popoverBezierPathWithRect:(NSRect)aRect;
@end

@implementation INPopoverWindowFrame
@synthesize color = _color, borderColor = _borderColor, topHighlightColor=_topHighlightColor;
@synthesize borderWidth = _borderWidth;
@synthesize arrowDirection = _arrowDirection;
@synthesize arrowOffset = _arrowOffset;
@synthesize animating = _animating;
@synthesize useGlassBackground = _useGlassBackground;

- (id)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		// Set some default values
		self.arrowDirection = INPopoverArrowDirectionLeft;
		self.color = [NSColor colorWithCalibratedWhite:0.0 alpha:0.8];
	}
	return self;
}

- (void)dealloc
{
	[_color release];
	[_borderColor release];
	[_topHighlightColor release];
	[super dealloc];
}

- (void)setFrame:(NSRect)frameRect
{
	[super setFrame:frameRect];
}

// Based off of discusion: http://www.cocoadev.com/index.pl?ScreenShotCode
- (CIImage *)blurredScreenImageWithBlurRadius:(CGFloat)blurRadius
{
    // Get the CGWindowID of supplied window
    CGWindowID windowID = (CGWindowID) [[self window] windowNumber];
    
    // Get window's rect in flipped screen coordinates
    CGRect windowRect = NSRectToCGRect([[self window] frame]);
    windowRect.origin.y = NSMaxY([[[self window] screen] frame]) - NSMaxY([[self window] frame]);
    
    // Get a composite image of all the windows beneath your window
    CGImageRef capturedImage = CGWindowListCreateImage( windowRect, kCGWindowListOptionOnScreenBelowWindow, windowID, kCGWindowImageDefault );
    
    if(CGImageGetWidth(capturedImage) <= 1) {
        CGImageRelease(capturedImage);
        return nil;
    }
    
	CIImage *sourceImage = [CIImage imageWithCGImage:capturedImage];
    CGImageRelease(capturedImage);
	
	if (blurRadius == 0) {
		return sourceImage;
	}
	
	CIFilter *gaussianBlur = [CIFilter filterWithName:@"CIGaussianBlur"]; 
	[gaussianBlur setValue:sourceImage forKey:@"inputImage"];
	[gaussianBlur setValue:[NSNumber numberWithFloat:blurRadius] forKey:@"inputRadius"];
	
	return [gaussianBlur valueForKey:@"outputImage"];
}

- (void)drawRect:(NSRect)dirtyRect
{
	NSBezierPath *path = [self _popoverBezierPathWithRect:[self bounds]];
	// Bezier paths draw *on* the path. This transformation its offset and does a proper, crisp drawing
	// by not using internally using fractional pixels and subsequent anti-aliasing.
	
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy:_borderWidth/2 yBy:_borderWidth/2];
	[path transformUsingAffineTransform:transform];
	
	[self.color set];

	if (self.useGlassBackground && ![self isAnimating] && self.color.alphaComponent != 1) {
		[path setClip];
		
		CIImage *backgroundImage = [self blurredScreenImageWithBlurRadius:1.2];
		[backgroundImage drawInRect:[self bounds] fromRect:[self bounds] operation:NSCompositeSourceOver fraction:1.0];
	}		

	[path fill];	

	[path setLineWidth:self.borderWidth];
	[self.borderColor set];
	
	[path stroke];
	
	if (self.topHighlightColor) {
		[self.topHighlightColor set];
		NSRect bounds = NSInsetRect([self bounds], INPOPOVER_ARROW_HEIGHT, INPOPOVER_ARROW_HEIGHT);
		NSRect lineRect = NSMakeRect(floor(NSMinX(bounds) + (INPOPOVER_CORNER_RADIUS / 2.0)), NSMaxY(bounds) - self.borderWidth - 1, NSWidth(bounds) - INPOPOVER_CORNER_RADIUS, 1.0);
		
		if (self.arrowDirection == INPopoverArrowDirectionUp) {
			CGFloat width = floor((lineRect.size.width / 2.0) - (INPOPOVER_ARROW_WIDTH / 2.0));
			NSRectFill(NSMakeRect(lineRect.origin.x, lineRect.origin.y, width, lineRect.size.height));
			NSRectFill(NSMakeRect(floor(lineRect.origin.x + (lineRect.size.width / 2.0) + (INPOPOVER_ARROW_WIDTH / 2.0)), lineRect.origin.y, width, lineRect.size.height));
		} else {
			NSRectFill(lineRect);
		}
	}
}

#pragma mark -
#pragma mark Private

- (NSBezierPath*)_popoverBezierPathWithRect:(NSRect)aRect
{
	CGFloat radius = INPOPOVER_CORNER_RADIUS;
	CGFloat inset = radius + INPOPOVER_ARROW_HEIGHT + _borderWidth;
	NSRect drawingRect = NSInsetRect(aRect, inset, inset);
	CGFloat minX = NSMinX(drawingRect);
	CGFloat maxX = NSMaxX(drawingRect);
	CGFloat minY = NSMinY(drawingRect);
	CGFloat maxY = NSMaxY(drawingRect);
	
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineJoinStyle:NSRoundLineJoinStyle];
	
	// Bottom left corner
	[path appendBezierPathWithArcWithCenter:NSMakePoint(minX, minY) radius:radius startAngle:180.0 endAngle:270.0];
	if (self.arrowDirection == INPopoverArrowDirectionDown) {
		CGFloat midX = NSMidX(drawingRect) + _arrowOffset;
		midX = MIN(midX, maxX - inset);
		midX = MAX(inset + radius + floor(INPOPOVER_ARROW_WIDTH/2.0), midX);

		NSPoint points[3];
		points[0] = NSMakePoint(floor(midX - (INPOPOVER_ARROW_WIDTH / 2.0)), minY - radius); // Starting point
		points[1] = NSMakePoint(floor(midX), points[0].y - INPOPOVER_ARROW_HEIGHT); // Arrow tip
		points[2] = NSMakePoint(floor(midX + (INPOPOVER_ARROW_WIDTH / 2.0)), points[0].y); // Ending point
		[path appendBezierPathWithPoints:points count:3];
	}
	// Bottom right corner
	[path appendBezierPathWithArcWithCenter:NSMakePoint(maxX, minY) radius:radius startAngle:270.0 endAngle:360.0];
	if (self.arrowDirection == INPopoverArrowDirectionRight) {
		CGFloat midY = NSMidY(drawingRect);
		NSPoint points[3];
		points[0] = NSMakePoint(maxX + radius, floor(midY - (INPOPOVER_ARROW_WIDTH / 2.0)));
		points[1] = NSMakePoint(points[0].x + INPOPOVER_ARROW_HEIGHT, floor(midY));
		points[2] = NSMakePoint(points[0].x, floor(midY + (INPOPOVER_ARROW_WIDTH / 2.0)));
		[path appendBezierPathWithPoints:points count:3];
	}
	// Top right corner
	[path appendBezierPathWithArcWithCenter:NSMakePoint(maxX, maxY) radius:radius startAngle:0.0 endAngle:90.0];
	if (self.arrowDirection == INPopoverArrowDirectionUp) {
		CGFloat midX = NSMidX(drawingRect) + _arrowOffset;
		midX = MIN(midX, maxX - inset);
		midX = MAX(inset + radius + floor(INPOPOVER_ARROW_WIDTH/2.0), midX);
		
		NSPoint points[3];
		points[0] = NSMakePoint(floor(midX + (INPOPOVER_ARROW_WIDTH / 2.0)), maxY + radius);
		points[1] = NSMakePoint(floor(midX), points[0].y + INPOPOVER_ARROW_HEIGHT);
		points[2] = NSMakePoint(floor(midX - (INPOPOVER_ARROW_WIDTH / 2.0)), points[0].y);
		[path appendBezierPathWithPoints:points count:3];
	}
	// Top left corner
	[path appendBezierPathWithArcWithCenter:NSMakePoint(minX, maxY) radius:radius startAngle:90.0 endAngle:180.0];
	if (self.arrowDirection == INPopoverArrowDirectionLeft) {
		CGFloat midY = NSMidY(drawingRect);
		NSPoint points[3];
		points[0] = NSMakePoint(minX - radius, floor(midY + (INPOPOVER_ARROW_WIDTH / 2.0)));
		points[1] = NSMakePoint(points[0].x - INPOPOVER_ARROW_HEIGHT, floor(midY));
		points[2] = NSMakePoint(points[0].x, floor(midY - (INPOPOVER_ARROW_WIDTH / 2.0)));
		[path appendBezierPathWithPoints:points count:3];
	}
	[path closePath];
	
	return path;
}

#pragma mark -
#pragma mark Accessors

// Redraw the frame every time a property is changed
- (void)setColor:(NSColor *)newColor
{
	if (_color != newColor) {
		[_color release];
		_color = [newColor retain];
		[self setNeedsDisplay:YES];
	}
}

- (void)setBorderColor:(NSColor *)newBorderColor
{
	if (_borderColor != newBorderColor) {
		[_borderColor release];
		_borderColor = [newBorderColor retain];
		[self setNeedsDisplay:YES];
	}
}

- (void)setArrowDirection:(INPopoverArrowDirection)newArrowDirection
{
	_arrowDirection = newArrowDirection;
	[self setNeedsDisplay:YES];
}

- (void)setBorderWidth:(CGFloat)newBorderWidth
{
	_borderWidth = newBorderWidth;
	[self setNeedsDisplay:YES];
}

@end
