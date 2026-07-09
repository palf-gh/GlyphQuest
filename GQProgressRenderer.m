#import "GQThemeSpec.h"

static CGFloat GQNumberValue(id value, CGFloat fallback) {
	if ([value isKindOfClass:[NSNumber class]]) {
		return [(NSNumber *)value doubleValue];
	}
	return fallback;
}

static BOOL GQBoolValue(id value, BOOL fallback) {
	if ([value isKindOfClass:[NSNumber class]]) {
		return [(NSNumber *)value boolValue];
	}
	return fallback;
}

static NSString *GQStringValue(id value, NSString *fallback) {
	if ([value isKindOfClass:[NSString class]]) {
		return (NSString *)value;
	}
	return fallback;
}

static void GQDrawStarAtPoint(NSPoint point, CGFloat radius, NSColor *color) {
	[color setFill];
	NSBezierPath *star = [NSBezierPath bezierPath];
	[star moveToPoint:NSMakePoint(point.x, point.y - radius)];
	[star lineToPoint:NSMakePoint(point.x + radius * 0.26, point.y - radius * 0.26)];
	[star lineToPoint:NSMakePoint(point.x + radius, point.y)];
	[star lineToPoint:NSMakePoint(point.x + radius * 0.26, point.y + radius * 0.26)];
	[star lineToPoint:NSMakePoint(point.x, point.y + radius)];
	[star lineToPoint:NSMakePoint(point.x - radius * 0.26, point.y + radius * 0.26)];
	[star lineToPoint:NSMakePoint(point.x - radius, point.y)];
	[star lineToPoint:NSMakePoint(point.x - radius * 0.26, point.y - radius * 0.26)];
	[star closePath];
	[star fill];
}

static void GQDrawDiamondAtPoint(NSPoint point, CGFloat radius, NSColor *color, BOOL stroke, CGFloat strokeWidth) {
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:NSMakePoint(point.x, point.y - radius)];
	[path lineToPoint:NSMakePoint(point.x + radius, point.y)];
	[path lineToPoint:NSMakePoint(point.x, point.y + radius)];
	[path lineToPoint:NSMakePoint(point.x - radius, point.y)];
	[path closePath];
	if (stroke) {
		[color setStroke];
		path.lineWidth = strokeWidth;
		[path stroke];
	} else {
		[color setFill];
		[path fill];
	}
}

static CGFloat GQShapeY(NSString *yKey, NSRect rect, CGFloat size, NSUInteger index, NSUInteger seed) {
	if ([yKey isEqualToString:@"top"]) {
		return NSMinY(rect) + size;
	}
	if ([yKey isEqualToString:@"bottom"]) {
		return NSMaxY(rect) - size;
	}
	if ([yKey isEqualToString:@"jitter"]) {
		return NSMinY(rect) + size + (CGFloat)((index + seed) % 5);
	}
	return NSMidY(rect);
}

static void GQDrawImageOverlay(NSBundle *bundle, GQThemeSpec *theme, NSDictionary *overlay, NSRect rect) {
	NSString *file = GQStringValue(overlay[@"file"], nil);
	if (file.length == 0) {
		return;
	}
	NSString *name = [file stringByDeletingPathExtension];
	NSString *extension = file.pathExtension.length > 0 ? file.pathExtension : @"png";
	NSImage *image = [[NSImage alloc] initWithContentsOfURL:[bundle URLForResource:name withExtension:extension subdirectory:theme.resourceSubdirectory]];
	if (!image) {
		return;
	}
	NSString *mode = GQStringValue(overlay[@"mode"], @"stretch");
	CGFloat opacity = GQNumberValue(overlay[@"opacity"], 1.0);
	CGFloat inset = GQNumberValue(overlay[@"inset"], 0.0);
	NSRect drawRect = NSInsetRect(rect, inset, inset);
	[NSGraphicsContext saveGraphicsState];
	if ([mode isEqualToString:@"tile"]) {
		NSSize imageSize = image.size;
		if (imageSize.width <= 0.0 || imageSize.height <= 0.0) {
			[NSGraphicsContext restoreGraphicsState];
			return;
		}
		[[NSBezierPath bezierPathWithRect:drawRect] addClip];
		for (CGFloat y = NSMinY(drawRect); y < NSMaxY(drawRect); y += imageSize.height) {
			for (CGFloat x = NSMinX(drawRect); x < NSMaxX(drawRect); x += imageSize.width) {
				[image drawInRect:NSMakeRect(x, y, imageSize.width, imageSize.height)
						   fromRect:NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height)
						  operation:NSCompositingOperationSourceOver
						   fraction:opacity];
			}
		}
	} else {
		[image drawInRect:drawRect
				 fromRect:NSMakeRect(0.0, 0.0, image.size.width, image.size.height)
				operation:NSCompositingOperationSourceOver
				 fraction:opacity];
	}
	[NSGraphicsContext restoreGraphicsState];
}

static void GQDrawStripesInRect(NSRect rect, NSDictionary *layer) {
	NSColor *colour = GQColorFromHex(GQStringValue(layer[@"colour"], @"#FFFFFF29"));
	CGFloat angle = GQNumberValue(layer[@"angle"], -55.0);
	CGFloat width = GQNumberValue(layer[@"width"], 7.0);
	CGFloat spacing = GQNumberValue(layer[@"spacing"], 12.0);
	CGFloat offsetX = GQNumberValue(layer[@"offset_x"], 0.0);
	CGFloat radians = angle * M_PI / 180.0;
	CGFloat stepX = spacing * cos(radians);
	CGFloat stepY = spacing * sin(radians);
	CGFloat startX = NSMinX(rect) + offsetX - NSHeight(rect);
	[colour setFill];
	for (CGFloat x = startX; x < NSMaxX(rect) + NSHeight(rect); x += stepX, startX += stepY) {
		NSBezierPath *stripe = [NSBezierPath bezierPath];
		[stripe moveToPoint:NSMakePoint(x, NSMaxY(rect))];
		[stripe lineToPoint:NSMakePoint(x + width, NSMaxY(rect))];
		[stripe lineToPoint:NSMakePoint(x + width + NSHeight(rect), NSMinY(rect))];
		[stripe lineToPoint:NSMakePoint(x + NSHeight(rect), NSMinY(rect))];
		[stripe closePath];
		[stripe fill];
	}
}

static void GQDrawLinesInRect(NSRect rect, NSDictionary *layer) {
	NSColor *colour = GQColorFromHex(GQStringValue(layer[@"colour"], @"#FFFFFF40"));
	CGFloat angle = GQNumberValue(layer[@"angle"], 90.0);
	CGFloat spacing = GQNumberValue(layer[@"spacing"], 14.0);
	CGFloat thickness = GQNumberValue(layer[@"thickness"], 0.75);
	CGFloat inset = GQNumberValue(layer[@"inset"], 0.0);
	CGFloat offsetX = GQNumberValue(layer[@"offset_x"], 0.0);
	[colour setStroke];
	if (fabs(angle - 90.0) < 0.01) {
		for (CGFloat x = NSMinX(rect) + offsetX; x < NSMaxX(rect); x += spacing) {
			NSBezierPath *line = [NSBezierPath bezierPath];
			[line moveToPoint:NSMakePoint(x, NSMinY(rect) + inset)];
			[line lineToPoint:NSMakePoint(x, NSMaxY(rect) - inset)];
			line.lineWidth = thickness;
			[line stroke];
		}
		return;
	}
	CGFloat radians = angle * M_PI / 180.0;
	for (CGFloat x = NSMinX(rect) + offsetX; x < NSMaxX(rect); x += spacing) {
		NSBezierPath *line = [NSBezierPath bezierPath];
		[line moveToPoint:NSMakePoint(x, NSMinY(rect) + inset)];
		[line lineToPoint:NSMakePoint(x + cos(radians) * NSHeight(rect), NSMaxY(rect) - inset)];
		line.lineWidth = thickness;
		[line stroke];
	}
}

static void GQDrawGridInRect(NSRect rect, NSDictionary *layer) {
	NSColor *colour = GQColorFromHex(GQStringValue(layer[@"colour"], @"#FFFFFF22"));
	CGFloat xSpacing = GQNumberValue(layer[@"x_spacing"], 10.0);
	CGFloat ySpacing = GQNumberValue(layer[@"y_spacing"], 4.0);
	CGFloat thickness = GQNumberValue(layer[@"thickness"], 0.5);
	[colour setStroke];
	for (CGFloat x = NSMinX(rect); x < NSMaxX(rect); x += xSpacing) {
		NSBezierPath *line = [NSBezierPath bezierPath];
		[line moveToPoint:NSMakePoint(x, NSMinY(rect))];
		[line lineToPoint:NSMakePoint(x, NSMaxY(rect))];
		line.lineWidth = thickness;
		[line stroke];
	}
	for (CGFloat y = NSMinY(rect); y < NSMaxY(rect); y += ySpacing) {
		NSBezierPath *line = [NSBezierPath bezierPath];
		[line moveToPoint:NSMakePoint(NSMinX(rect), y)];
		[line lineToPoint:NSMakePoint(NSMaxX(rect), y)];
		line.lineWidth = thickness;
		[line stroke];
	}
}

static void GQDrawSpeckleInRect(NSRect rect, NSDictionary *layer) {
	NSColor *colour = GQColorFromHex(GQStringValue(layer[@"colour"], @"#FFFFFF66"));
	CGFloat density = GQNumberValue(layer[@"density"], 0.3);
	CGFloat size = GQNumberValue(layer[@"size"], 1.2);
	NSUInteger seed = (NSUInteger)GQNumberValue(layer[@"seed"], 42.0);
	[colour setFill];
	NSUInteger count = (NSUInteger)fmax(1.0, NSWidth(rect) * NSHeight(rect) * density * 0.05);
	for (NSUInteger index = 0; index < count; index++) {
		NSUInteger hash = (index + 1) * 1103515245 + seed;
		CGFloat x = NSMinX(rect) + (CGFloat)(hash % 10000) / 10000.0 * NSWidth(rect);
		CGFloat y = NSMinY(rect) + (CGFloat)((hash / 10000) % 10000) / 10000.0 * NSHeight(rect);
		NSRect dot = NSMakeRect(x, y, size, size);
		[[NSBezierPath bezierPathWithOvalInRect:dot] fill];
	}
}

static void GQDrawShapesInRect(NSRect rect, NSDictionary *layer) {
	NSString *shape = GQStringValue(layer[@"shape"], @"oval");
	NSColor *colour = GQColorFromHex(GQStringValue(layer[@"colour"], @"#FFFFFF40"));
	CGFloat spacing = GQNumberValue(layer[@"spacing"], 16.0);
	CGFloat size = GQNumberValue(layer[@"size"], 2.0);
	CGFloat sizeAlt = GQNumberValue(layer[@"size_alt"], size);
	CGFloat offsetX = GQNumberValue(layer[@"offset_x"], 0.0);
	NSString *yKey = GQStringValue(layer[@"y"], @"mid");
	BOOL stroke = GQBoolValue(layer[@"stroke"], NO);
	CGFloat strokeWidth = GQNumberValue(layer[@"stroke_width"], 0.8);
	NSUInteger seed = (NSUInteger)GQNumberValue(layer[@"seed"], 0.0);
	NSUInteger index = 0;
	for (CGFloat x = NSMinX(rect) + offsetX; x < NSMaxX(rect) - 2.0; x += spacing, index++) {
		CGFloat radius = fmod(x + seed, spacing * 2.0) < spacing ? size : sizeAlt;
		NSPoint point = NSMakePoint(x, GQShapeY(yKey, rect, radius, index, seed));
		if ([shape isEqualToString:@"star"]) {
			GQDrawStarAtPoint(point, radius, colour);
		} else if ([shape isEqualToString:@"diamond"]) {
			GQDrawDiamondAtPoint(point, radius, colour, stroke, strokeWidth);
		} else if ([shape isEqualToString:@"rect"]) {
			CGFloat insetY = GQNumberValue(layer[@"inset_y"], 2.0);
			CGFloat width = GQNumberValue(layer[@"width"], 4.0);
			NSRect segment = NSMakeRect(x, NSMinY(rect) + insetY, width, fmax(1.0, NSHeight(rect) - insetY * 2.0));
			if (stroke) {
				[colour setStroke];
				NSBezierPath *path = [NSBezierPath bezierPathWithRect:segment];
				path.lineWidth = strokeWidth;
				[path stroke];
			} else {
				[colour setFill];
				[[NSBezierPath bezierPathWithRect:segment] fill];
			}
		} else {
			NSRect oval = NSMakeRect(point.x - radius, point.y - radius, radius * 2.0, radius * 2.0);
			NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:oval];
			if (stroke) {
				[colour setStroke];
				path.lineWidth = strokeWidth;
				[path stroke];
			} else {
				[colour setFill];
				[path fill];
			}
		}
	}
}

static void GQDrawGradientInRect(NSRect rect, NSDictionary *layer) {
	NSArray *colours = GQColorsFromHexArray(layer[@"colours"]);
	if (colours.count == 0) {
		return;
	}
	CGFloat angle = GQNumberValue(layer[@"angle"], 90.0);
	NSGradient *gradient = [[NSGradient alloc] initWithColors:colours];
	[gradient drawInRect:rect angle:angle];
}

static void GQDrawLayerInRect(NSRect rect, NSDictionary *layer, NSBundle *bundle, GQThemeSpec *theme) {
	NSString *kind = GQStringValue(layer[@"kind"], nil);
	if ([kind isEqualToString:@"stripes"]) {
		GQDrawStripesInRect(rect, layer);
	} else if ([kind isEqualToString:@"lines"]) {
		GQDrawLinesInRect(rect, layer);
	} else if ([kind isEqualToString:@"grid"]) {
		GQDrawGridInRect(rect, layer);
	} else if ([kind isEqualToString:@"speckle"]) {
		GQDrawSpeckleInRect(rect, layer);
	} else if ([kind isEqualToString:@"shapes"]) {
		GQDrawShapesInRect(rect, layer);
	} else if ([kind isEqualToString:@"gradient"]) {
		GQDrawGradientInRect(rect, layer);
	} else if ([kind isEqualToString:@"image"]) {
		GQDrawImageOverlay(bundle, theme, layer, rect);
	}
}

static void GQDrawLayersInRect(NSRect rect, NSArray<NSDictionary *> *layers, NSBundle *bundle, GQThemeSpec *theme) {
	for (NSDictionary *layer in layers) {
		if ([layer isKindOfClass:[NSDictionary class]]) {
			GQDrawLayerInRect(rect, layer, bundle, theme);
		}
	}
}

static NSArray<NSColor *> *GQFillColorsForProgress(GQProgressStyle *style, CGFloat progress) {
	if (progress >= GQProgressCompleteThreshold) {
		return style.completeFillColors.count > 0 ? style.completeFillColors : style.fillColors;
	}
	if (progress >= GQProgressNearThreshold) {
		return style.nearFillColors.count > 0 ? style.nearFillColors : style.fillColors;
	}
	return style.fillColors;
}

static NSColor *GQStrokeColorForProgress(GQProgressStyle *style, CGFloat progress) {
	if (progress >= GQProgressCompleteThreshold) {
		return style.completeFillStrokeColor;
	}
	if (progress >= GQProgressNearThreshold) {
		return style.nearFillStrokeColor;
	}
	return style.fillStrokeColor;
}

@implementation GQProgressRenderer

+ (void)drawProgressInRect:(NSRect)bounds
                  progress:(CGFloat)progress
                     large:(BOOL)large
                     theme:(GQThemeSpec *)theme
                    bundle:(NSBundle *)bundle {
	if (NSWidth(bounds) < 8.0 || NSHeight(bounds) < 4.0) {
		return;
	}
	GQProgressStyle *style = theme.progressStyle;
	if (!style) {
		return;
	}

	NSRect bezelRect = large ? NSInsetRect(bounds, 0.5, 1.0) : bounds;
	CGFloat bezelRadius = [style radiusForKey:@"bezel_radius" height:NSHeight(bezelRect) large:large];
	NSBezierPath *bezel = [NSBezierPath bezierPathWithRoundedRect:bezelRect xRadius:bezelRadius yRadius:bezelRadius];

	NSShadow *shadow = [[NSShadow alloc] init];
	shadow.shadowColor = style.shadowColor;
	shadow.shadowBlurRadius = large ? 2.0 : 1.0;
	shadow.shadowOffset = NSMakeSize(0.0, large ? -1.0 : -0.5);
	[NSGraphicsContext saveGraphicsState];
	[shadow set];
	[style.bezelBottomColor setFill];
	[bezel fill];
	[NSGraphicsContext restoreGraphicsState];

	NSGradient *bezelGradient = [[NSGradient alloc] initWithColors:@[style.bezelTopColor, style.bezelBottomColor]];
	[bezelGradient drawInBezierPath:bezel angle:-90.0];

	NSDictionary *bezelOverlay = [style.overlays[@"bezel"] isKindOfClass:[NSDictionary class]] ? style.overlays[@"bezel"] : nil;
	if (bezelOverlay) {
		GQDrawImageOverlay(bundle, theme, bezelOverlay, bezelRect);
	}

	[style.bezelStrokeColor setStroke];
	bezel.lineWidth = 1.0;
	[bezel stroke];

	NSRect trackRect = large ? NSInsetRect(bezelRect, 3.0, 3.0) : NSInsetRect(bezelRect, 1.5, 1.5);
	CGFloat trackRadius = [style radiusForKey:@"track_radius" height:NSHeight(trackRect) large:large];
	NSBezierPath *track = [NSBezierPath bezierPathWithRoundedRect:trackRect xRadius:trackRadius yRadius:trackRadius];
	[NSGraphicsContext saveGraphicsState];
	[track addClip];
	NSGradient *trackGradient = [[NSGradient alloc] initWithColors:@[style.trackTopColor, style.trackBottomColor]];
	[trackGradient drawInRect:trackRect angle:90.0];
	GQDrawLayersInRect(trackRect, style.trackLayers, bundle, theme);
	NSDictionary *trackOverlay = [style.overlays[@"track"] isKindOfClass:[NSDictionary class]] ? style.overlays[@"track"] : nil;
	if (trackOverlay) {
		GQDrawImageOverlay(bundle, theme, trackOverlay, trackRect);
	}
	[NSGraphicsContext restoreGraphicsState];

	CGFloat fillWidth = NSWidth(trackRect) * (progress / 100.0);
	if (fillWidth >= 2.0) {
		NSRect fillRect = NSMakeRect(NSMinX(trackRect), NSMinY(trackRect), fillWidth, NSHeight(trackRect));
		CGFloat fillRadius = [style radiusForKey:@"fill_radius" height:NSHeight(fillRect) large:large];
		NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:fillRadius yRadius:fillRadius];
		[NSGraphicsContext saveGraphicsState];
		[fillPath addClip];
		if ([style.fillMode isEqualToString:@"segments"]) {
			CGFloat segmentWidth = GQNumberValue(style.segments[@"width"], 4.0);
			CGFloat gap = GQNumberValue(style.segments[@"gap"], 5.0);
			CGFloat insetY = GQNumberValue(style.segments[@"inset_y"], 2.0);
			NSArray<NSColor *> *fillColors = GQFillColorsForProgress(style, progress);
			NSColor *segmentColor = fillColors.firstObject ?: NSColor.systemBlueColor;
			[segmentColor setFill];
			for (CGFloat x = NSMinX(fillRect); x < NSMaxX(fillRect); x += segmentWidth + gap) {
				NSRect segment = NSMakeRect(x, NSMinY(fillRect) + insetY, segmentWidth, fmax(1.0, NSHeight(fillRect) - insetY * 2.0));
				[[NSBezierPath bezierPathWithRect:segment] fill];
			}
		} else {
			NSGradient *fillGradient = [[NSGradient alloc] initWithColors:GQFillColorsForProgress(style, progress)];
			[fillGradient drawInRect:fillRect angle:90.0];
		}
		GQDrawLayersInRect(fillRect, style.fillLayers, bundle, theme);
		NSDictionary *fillOverlay = [style.overlays[@"fill"] isKindOfClass:[NSDictionary class]] ? style.overlays[@"fill"] : nil;
		if (fillOverlay) {
			GQDrawImageOverlay(bundle, theme, fillOverlay, fillRect);
		}

		if (GQBoolValue(style.gloss[@"enabled"], YES)) {
			NSColor *glossColor = GQColorFromHex(GQStringValue(style.gloss[@"colour"], @"#FFFFFF"));
			CGFloat glossAlpha = GQNumberValue(style.gloss[@"alpha"], large ? 0.22 : 0.18);
			CGFloat glossRadius = [style radiusForKey:@"gloss_radius" height:NSHeight(fillRect) large:large];
			NSRect glossRect = large
				? NSMakeRect(NSMinX(fillRect) + 2.0, NSMinY(fillRect) + 2.0, fmax(0.0, NSWidth(fillRect) - 4.0), NSHeight(fillRect) * 0.34)
				: NSMakeRect(NSMinX(fillRect) + 1.0, NSMaxY(fillRect) - fmax(1.0, NSHeight(fillRect) * 0.4) - 1.0, fmax(0.0, NSWidth(fillRect) - 2.0), fmax(1.0, NSHeight(fillRect) * 0.4));
			NSBezierPath *gloss = [NSBezierPath bezierPathWithRoundedRect:glossRect xRadius:glossRadius yRadius:glossRadius];
			[[glossColor colorWithAlphaComponent:glossAlpha] setFill];
			[gloss fill];
		}
		[NSGraphicsContext restoreGraphicsState];

		[GQStrokeColorForProgress(style, progress) setStroke];
		fillPath.lineWidth = 1.0;
		[fillPath stroke];
	}

	if (large && style.trackStrokeColor) {
		[style.trackStrokeColor setStroke];
		track.lineWidth = 0.75;
		[track stroke];
	}

	if (style.rimColor) {
		[style.rimColor setStroke];
		CGFloat rimInset = large ? 1.25 : 0.75;
		NSBezierPath *rim = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bezelRect, rimInset, rimInset)
															xRadius:fmax(1.0, bezelRadius - rimInset)
															yRadius:fmax(1.0, bezelRadius - rimInset)];
		rim.lineWidth = 0.75;
		[rim stroke];
	}
}

@end
