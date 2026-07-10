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
	return @[@"forest", @"cyber", @"moonlight", @"candy", @"ocean", @"y2k"];
}

static NSString *GQLocalizedThemeName(GQThemeSpec *theme, NSString *locale) {
	if ([locale isEqualToString:@"ja"]) {
		return theme.japaneseName;
	}
	if ([locale isEqualToString:@"zh"]) {
		return theme.chineseName;
	}
	if ([locale isEqualToString:@"ko"]) {
		return theme.koreanName;
	}
	return theme.englishName;
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

	const CGFloat columns = 3.0;
	const CGFloat shadowInset = 4.0;

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

		NSRect shadowRect = NSMakeRect(x - shadowInset, y - shadowInset * 0.5, GQSamplePanelWidth + shadowInset * 2.0, GQSamplePanelHeight + shadowInset * 2.0);
		NSBezierPath *shadowPath = [NSBezierPath bezierPathWithRoundedRect:shadowRect xRadius:10.0 yRadius:10.0];
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.16] setFill];
		[shadowPath fill];

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

static NSImage *GQSnapshotView(NSView *view, CGFloat scale) {
	NSSize size = view.bounds.size;
	NSRect frame = NSMakeRect(0.0, 0.0, size.width, size.height);

	NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
												   styleMask:NSWindowStyleMaskBorderless
													 backing:NSBackingStoreBuffered
													   defer:NO];
	window.releasedWhenClosed = NO;
	window.opaque = NO;
	window.backgroundColor = NSColor.clearColor;

	NSView *host = [[NSView alloc] initWithFrame:frame];
	host.wantsLayer = NO;
	window.contentView = host;
	view.frame = frame;
	view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[host addSubview:view];

	[view layoutSubtreeIfNeeded];
	[window displayIfNeeded];

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
	[view cacheDisplayInRect:view.bounds toBitmapImageRep:representation];

	NSImage *image = [[NSImage alloc] initWithSize:size];
	[image addRepresentation:representation];
	return image;
}

static NSImage *GQCompositeGallery(NSArray<NSImage *> *panels, NSArray<NSString *> *labels, CGFloat scale) {
	const CGFloat columns = 3.0;
	const CGFloat rows = 2.0;

	CGFloat galleryWidth = GQGalleryPadding * 2.0 + columns * GQSamplePanelWidth + (columns - 1.0) * GQGalleryGapX;
	CGFloat galleryHeight = GQGalleryPadding * 2.0 + rows * (GQSamplePanelHeight + GQGalleryLabelHeight) + (rows - 1.0) * GQGalleryGapY;

	GQGalleryCompositorView *compositor = [[GQGalleryCompositorView alloc] initWithFrame:NSMakeRect(0.0, 0.0, galleryWidth, galleryHeight)];
	compositor.panels = panels;
	compositor.labels = labels;
	return GQSnapshotView(compositor, scale);
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

	for (NSString *themeID in GQThemeOrder()) {
		GQThemeSpec *theme = GQThemeForIdentifier(themeID);
		GQPalettePanelView *panel = [[GQPalettePanelView alloc] initWithFrame:NSMakeRect(0.0, 0.0, GQSamplePanelWidth, GQSamplePanelHeight)];
		panel.resourceBundle = resourceBundle;
		panel.captureCompositing = YES;
		panel.theme = theme;
		[panel buildInterfaceIfNeeded];
		[panel applyTheme:theme];
		[panel setOverviewProgress:GQSampleProgress scoreSum:(CGFloat)GQSampleScoreSum totalCount:GQSampleTotalGlyphs];
		[panel updateModeVisibility];
		[panel layoutPanel];
		[panels addObject:GQSnapshotView(panel, scale)];
		[labels addObject:GQLocalizedThemeName(theme, locale)];
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
