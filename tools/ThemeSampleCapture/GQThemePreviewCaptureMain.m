#import <Cocoa/Cocoa.h>
#import <string.h>

#import "GQPalettePanel.h"
#import "GQThemeSpec.h"

static const CGFloat GQSamplePanelWidth = 300.0;
static const CGFloat GQSamplePanelHeight = 190.0;
static const NSUInteger GQSampleScoreSum = 746;
static const NSUInteger GQSampleTotalGlyphs = 3347;
static const CGFloat GQSampleProgress = (746.0 / 3347.0) * 100.0;

static NSArray<NSString *> *GQThemeOrder(void) {
	return @[@"system-light", @"system-dark", @"forest", @"cyber", @"moonlight", @"candy", @"ocean", @"y2k", @"strike", @"leather"];
}

static NSString *GQThemeIDForOrderEntry(NSString *entry) {
	if ([entry hasPrefix:@"system-"] || [entry hasPrefix:@"native-"]) {
		return @"system";
	}
	return entry;
}

static NSAppearance *GQAppearanceForOrderEntry(NSString *entry) {
	if ([entry isEqualToString:@"system-dark"] || [entry isEqualToString:@"native-dark"]) {
		return [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
	}
	if ([entry isEqualToString:@"system-light"] || [entry isEqualToString:@"native-light"]) {
		return [NSAppearance appearanceNamed:NSAppearanceNameAqua];
	}
	return nil;
}

static NSString *GQLocalizedThemeName(GQThemeSpec *theme, NSString *locale, NSString *orderEntry) {
	NSString *base = nil;
	if ([locale isEqualToString:@"ja"]) {
		base = theme.japaneseName;
	} else if ([locale isEqualToString:@"zh"]) {
		base = theme.chineseName;
	} else if ([locale isEqualToString:@"ko"]) {
		base = theme.koreanName;
	} else {
		base = theme.englishName;
	}

	if ([orderEntry isEqualToString:@"system-light"] || [orderEntry isEqualToString:@"native-light"]) {
		if ([locale isEqualToString:@"ja"]) {
			return [base stringByAppendingString:@" · ライト"];
		}
		if ([locale isEqualToString:@"zh"]) {
			return [base stringByAppendingString:@" · 浅色"];
		}
		if ([locale isEqualToString:@"ko"]) {
			return [base stringByAppendingString:@" · 라이트"];
		}
		return [base stringByAppendingString:@" · Light"];
	}
	if ([orderEntry isEqualToString:@"system-dark"] || [orderEntry isEqualToString:@"native-dark"]) {
		if ([locale isEqualToString:@"ja"]) {
			return [base stringByAppendingString:@" · ダーク"];
		}
		if ([locale isEqualToString:@"zh"]) {
			return [base stringByAppendingString:@" · 深色"];
		}
		if ([locale isEqualToString:@"ko"]) {
			return [base stringByAppendingString:@" · 다크"];
		}
		return [base stringByAppendingString:@" · Dark"];
	}
	return base;
}

static const CGFloat GQGalleryPadding = 56.0;
static const CGFloat GQGalleryGapX = 48.0;
static const CGFloat GQGalleryGapY = 44.0;
static const CGFloat GQGalleryLabelHeight = 28.0;

static void GQClearBitmapRep(NSBitmapImageRep *representation) {
	unsigned char *bitmapData = representation.bitmapData;
	if (bitmapData) {
		memset(bitmapData, 0, (size_t)representation.bytesPerRow * (size_t)representation.pixelsHigh);
	}
}

@interface GQGalleryCompositorView : NSView
@property (nonatomic, copy) NSArray<NSImage *> *panels;
@property (nonatomic, copy) NSArray<NSString *> *labels;
@end

@implementation GQGalleryCompositorView

- (BOOL)isFlipped {
	return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	(void)dirtyRect;

	const CGFloat columns = 4.0;

	[[NSColor colorWithCalibratedRed:248.0 / 255.0 green:246.0 / 255.0 blue:242.0 / 255.0 alpha:1.0] setFill];
	NSRectFill(self.bounds);

	NSFont *labelFont = [NSFont systemFontOfSize:15.0 weight:NSFontWeightSemibold];
	NSDictionary *labelAttributes = @{
		NSFontAttributeName: labelFont,
		NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.20 alpha:1.0],
	};

	for (NSUInteger index = 0; index < self.panels.count; index++) {
		NSUInteger column = index % (NSUInteger)columns;
		NSUInteger row = index / (NSUInteger)columns;
		CGFloat x = GQGalleryPadding + (CGFloat)column * (GQSamplePanelWidth + GQGalleryGapX);
		CGFloat y = GQGalleryPadding + (CGFloat)row * (GQSamplePanelHeight + GQGalleryLabelHeight + GQGalleryGapY);

		NSImage *panel = self.panels[index];
		[panel drawInRect:NSMakeRect(x, y, GQSamplePanelWidth, GQSamplePanelHeight)
				 fromRect:NSMakeRect(0.0, 0.0, panel.size.width, panel.size.height)
				operation:NSCompositingOperationSourceOver
				 fraction:1.0
		   respectFlipped:YES
					hints:@{NSImageHintInterpolation: @(NSImageInterpolationHigh)}];

		NSString *label = self.labels[index];
		NSSize labelSize = [label sizeWithAttributes:labelAttributes];
		[label drawAtPoint:NSMakePoint(x + (GQSamplePanelWidth - labelSize.width) * 0.5, y + GQSamplePanelHeight + 8.0)
			  withAttributes:labelAttributes];
	}
}

@end

static NSImage *GQSnapshotView(NSView *view, CGFloat scale, NSAppearance *appearance, NSColor *backdropColour) {
	NSSize size = view.bounds.size;
	NSRect frame = NSMakeRect(0.0, 0.0, size.width, size.height);

	NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
												   styleMask:NSWindowStyleMaskBorderless
													 backing:NSBackingStoreBuffered
													   defer:NO];
	window.releasedWhenClosed = NO;
	window.opaque = backdropColour != nil;
	window.backgroundColor = backdropColour ?: NSColor.clearColor;
	window.alphaValue = 1.0;
	window.level = NSScreenSaverWindowLevel;
	[window setFrameOrigin:NSMakePoint(-10000.0, -10000.0)];
	if (appearance) {
		window.appearance = appearance;
	}

	NSView *host = [[NSView alloc] initWithFrame:frame];
	host.wantsLayer = YES;
	host.layer.backgroundColor = (backdropColour ?: NSColor.clearColor).CGColor;
	if (appearance) {
		host.appearance = appearance;
	}
	window.contentView = host;
	view.frame = frame;
	view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	if (appearance) {
		view.appearance = appearance;
	}
	[host addSubview:view];

	[view layoutSubtreeIfNeeded];
	[window layoutIfNeeded];
	[window orderFrontRegardless];
	[window displayIfNeeded];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];

	NSBitmapImageRep *representation = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
																			  pixelsWide:(NSInteger)ceil(size.width * scale)
																			  pixelsHigh:(NSInteger)ceil(size.height * scale)
																		   bitsPerSample:8
																		 samplesPerPixel:4
																				hasAlpha:YES
																				isPlanar:NO
																		  colorSpaceName:NSDeviceRGBColorSpace
																			 bytesPerRow:0
																		   bitsPerPixel:0];
	representation.size = size;
	GQClearBitmapRep(representation);
	[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:representation];
	[NSGraphicsContext setCurrentContext:context];
	context.imageInterpolation = NSImageInterpolationHigh;
	if (backdropColour) {
		[backdropColour setFill];
		NSRectFill(NSMakeRect(0.0, 0.0, size.width, size.height));
	}
	// Prefer the focused display path so AppKit push buttons draw their real bezel.
	[view displayRectIgnoringOpacity:view.bounds inContext:context];
	[NSGraphicsContext restoreGraphicsState];
	[window orderOut:nil];

	NSImage *image = [[NSImage alloc] initWithSize:size];
	[image addRepresentation:representation];
	return image;
}

static NSImage *GQCompositeGallery(NSArray<NSImage *> *panels, NSArray<NSString *> *labels, CGFloat scale) {
	const CGFloat columns = 4.0;
	const CGFloat rows = ceil((CGFloat)panels.count / columns);

	CGFloat galleryWidth = GQGalleryPadding * 2.0 + columns * GQSamplePanelWidth + (columns - 1.0) * GQGalleryGapX;
	CGFloat galleryHeight = GQGalleryPadding * 2.0 + rows * (GQSamplePanelHeight + GQGalleryLabelHeight) + fmax(0.0, rows - 1.0) * GQGalleryGapY;

	GQGalleryCompositorView *compositor = [[GQGalleryCompositorView alloc] initWithFrame:NSMakeRect(0.0, 0.0, galleryWidth, galleryHeight)];
	compositor.panels = panels;
	compositor.labels = labels;
	return GQSnapshotView(compositor, scale, nil, nil);
}

static BOOL GQWritePNG(NSImage *image, NSString *path) {
	NSBitmapImageRep *representation = nil;
	for (NSBitmapImageRep *candidate in image.representations) {
		if ([candidate isKindOfClass:[NSBitmapImageRep class]]) {
			representation = candidate;
			break;
		}
	}
	if (!representation) {
		return NO;
	}

	NSData *data = [representation representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	if (!data) {
		return NO;
	}
	return [data writeToFile:path atomically:YES];
}

static NSImage *GQRenderGalleryForLocale(NSString *locale, NSBundle *resourceBundle, CGFloat scale) {
	GQForceLanguageKey(locale);

	NSMutableArray<NSImage *> *panels = [NSMutableArray array];
	NSMutableArray<NSString *> *labels = [NSMutableArray array];

	for (NSString *orderEntry in GQThemeOrder()) {
		NSString *themeID = GQThemeIDForOrderEntry(orderEntry);
		GQThemeSpec *theme = GQThemeForIdentifier(themeID);
		NSAppearance *appearance = GQAppearanceForOrderEntry(orderEntry);

		GQPalettePanelView *panel = [[GQPalettePanelView alloc] initWithFrame:NSMakeRect(0.0, 0.0, GQSamplePanelWidth, GQSamplePanelHeight)];
		panel.resourceBundle = resourceBundle;
		panel.captureCompositing = YES;
		panel.theme = theme;
		[panel buildInterfaceIfNeeded];
		void (^configureAndCapture)(void) = ^{
			if (theme.usesNativeAppearance) {
				GQRefreshNativeThemeAppearance(theme);
			}
			[panel applyTheme:theme];
			[panel setOverviewProgress:GQSampleProgress scoreSum:(CGFloat)GQSampleScoreSum totalCount:GQSampleTotalGlyphs];
			[panel updateModeVisibility];
			[panel layoutPanel];
			NSColor *backdrop = nil;
			if (theme.usesNativeAppearance && [orderEntry hasSuffix:@"-dark"]) {
				// Dark samples need a flat plate; light sits on the gallery cream (no nested card).
				backdrop = [NSColor colorWithCalibratedWhite:0.18 alpha:1.0];
			}
			[panels addObject:GQSnapshotView(panel, scale, appearance, backdrop)];
			[labels addObject:GQLocalizedThemeName(theme, locale, orderEntry)];
		};
		if (appearance) {
			panel.appearance = appearance;
			[appearance performAsCurrentDrawingAppearance:configureAndCapture];
		} else {
			configureAndCapture();
		}
	}

	GQForceLanguageKey(nil);
	return GQCompositeGallery(panels, labels, scale);
}

int main(int argc, const char *argv[]) {
	(void)argc;
	(void)argv;

	@autoreleasepool {
		[NSApplication sharedApplication];
		[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];

		NSString *resourceBundlePath = [NSProcessInfo processInfo].environment[@"GLYPHQUEST_RESOURCE_BUNDLE"];
		if (resourceBundlePath.length == 0) {
			fprintf(stderr, "GLYPHQUEST_RESOURCE_BUNDLE is required\n");
			return 1;
		}

		NSBundle *resourceBundle = [NSBundle bundleWithPath:resourceBundlePath];
		if (!resourceBundle) {
			fprintf(stderr, "Could not open resource bundle at %s\n", resourceBundlePath.UTF8String);
			return 1;
		}

		NSString *outputDirectory = [NSProcessInfo processInfo].environment[@"GLYPHQUEST_SAMPLES_OUTPUT"];
		if (outputDirectory.length == 0) {
			outputDirectory = @"docs";
		}

		GQRegisterBundledFonts(resourceBundle);
		(void)GQThemeRegistry();

		CGFloat scale = 2.0;
		NSArray<NSString *> *locales = @[@"ja", @"zh", @"ko", @"en"];
		for (NSString *locale in locales) {
			NSImage *gallery = GQRenderGalleryForLocale(locale, resourceBundle, scale);
			NSString *outputPath = [outputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"theme-samples-%@.png", locale]];
			if (!GQWritePNG(gallery, outputPath)) {
				fprintf(stderr, "Failed to write %s\n", outputPath.UTF8String);
				return 1;
			}
			printf("Wrote %s\n", outputPath.UTF8String);
		}

		printf("Sample progress: %.1f%% (%lu / %lu glyphs)\n", GQSampleProgress, (unsigned long)GQSampleScoreSum, (unsigned long)GQSampleTotalGlyphs);
		return 0;
	}
}
