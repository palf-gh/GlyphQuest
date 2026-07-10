//
//  GlyphQuestPalette.m
//  GlyphQuest
//
//  Native Glyphs palette plugin (Glyphs integration only).
//

#import "GlyphQuestPalette.h"
#import "GQPalettePanel.h"
#import "GQThemeSpec.h"

#import <GlyphsCore/GSFont.h>
#import <GlyphsCore/GSFontMaster.h>
#import <GlyphsCore/GSGlyph.h>
#import <GlyphsCore/GSLayer.h>
#import <GlyphsCore/GSPaletteView.h>
#import <GlyphsCore/GSWindowControllerProtocol.h>
#import <math.h>

@protocol GlyphQuestFontDocument <NSObject>
- (GSFont *)font;
@end

@protocol GlyphQuestGlyphsApplication <NSObject>
- (id)currentFontDocument;
@end

@interface GlyphQuestRootView : GSPaletteView
@property (nonatomic, strong) GQPalettePanelView *panelView;
@end

@implementation GlyphQuestRootView

- (BOOL)isFlipped {
	return YES;
}

- (BOOL)isOpaque {
	return YES;
}

- (BOOL)allowsVibrancy {
	return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
	(void)dirtyRect;
}

- (void)layout {
	[super layout];
	self.panelView.frame = self.bounds;
	[self.panelView layoutPanel];
}

@end

@interface GlyphQuestProgressResult : NSObject
@property (nonatomic) CGFloat percent;
@property (nonatomic) CGFloat scoreSum;
@property (nonatomic) NSUInteger totalCount;
@property (nonatomic, copy) NSArray<GQScriptStat *> *scriptStats;
@end

@implementation GlyphQuestProgressResult
@end

@interface GlyphQuestPalette ()
@property (nonatomic, strong) GlyphQuestRootView *rootView;
@property (nonatomic, strong) GQPalettePanelView *panelView;
@property (nonatomic, strong) NSPopover *themePopover;
@property (nonatomic, strong) GQThemeSpec *currentTheme;
@property (nonatomic) NSUInteger paletteCurrentHeight;
@property (nonatomic) BOOL observing;
@end

@implementation GlyphQuestPalette

@synthesize windowController = _windowController;

- (instancetype)init {
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_paletteCurrentHeight = (NSUInteger)ceil(GQPaletteHeight);
		_currentTheme = GQSavedTheme();
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
	self.rootView = [[GlyphQuestRootView alloc] initWithFrame:NSMakeRect(0.0, 0.0, GQPaletteWidth, GQPaletteHeight)];
	self.rootView.controller = self;

	self.panelView = [[GQPalettePanelView alloc] initWithFrame:self.rootView.bounds];
	self.panelView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	self.panelView.captureCompositing = NO;
	self.panelView.theme = self.currentTheme;
	self.panelView.target = self;
	[self.panelView buildInterfaceIfNeeded];
	[self.rootView addSubview:self.panelView];
	self.rootView.panelView = self.panelView;

	self.view = self.rootView;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[self updateDisplay];
}

- (void)viewDidLayout {
	[super viewDidLayout];
	[self.panelView layoutPanel];
}

- (void)applyCurrentTheme {
	GQThemeSpec *theme = self.currentTheme ?: GQThemeForIdentifier(nil);
	self.currentTheme = theme;
	[self.panelView applyTheme:theme];
}

- (void)showThemePopover:(id)sender {
	(void)sender;
	if (self.themePopover.shown) {
		[self.themePopover close];
		return;
	}

	NSArray<GQThemeSpec *> *themes = GQThemeRegistry();
	CGFloat rowHeight = 32.0;
	NSSize contentSize = NSMakeSize(196.0, 12.0 + rowHeight * themes.count);
	NSViewController *contentController = [[NSViewController alloc] initWithNibName:nil bundle:nil];
	GQThemePopoverView *contentView = [[GQThemePopoverView alloc] initWithFrame:NSMakeRect(0.0, 0.0, contentSize.width, contentSize.height)];
	contentController.view = contentView;

	for (NSUInteger index = 0; index < themes.count; index++) {
		GQThemeSpec *theme = themes[index];
		GQThemeChoiceButton *button = [[GQThemeChoiceButton alloc] initWithFrame:NSMakeRect(8.0, 6.0 + index * rowHeight, contentSize.width - 16.0, rowHeight - 4.0)];
		button.themeSpec = theme;
		button.selectedTheme = [theme.identifier isEqualToString:self.currentTheme.identifier];
		button.target = self;
		button.action = @selector(themeChoiceSelected:);
		[contentView addSubview:button];
	}

	NSPopover *popover = [[NSPopover alloc] init];
	popover.behavior = NSPopoverBehaviorTransient;
	popover.contentSize = contentSize;
	popover.contentViewController = contentController;
	self.themePopover = popover;
	NSButton *settingsButton = self.panelView.settingsButton;
	[popover showRelativeToRect:settingsButton.bounds ofView:settingsButton preferredEdge:NSRectEdgeMaxY];
}

- (void)themeChoiceSelected:(id)sender {
	if (![sender isKindOfClass:GQThemeChoiceButton.class]) {
		return;
	}
	GQThemeChoiceButton *button = (GQThemeChoiceButton *)sender;
	GQThemeSpec *theme = GQThemeForIdentifier(button.themeSpec.identifier);
	self.currentTheme = theme;
	[[NSUserDefaults standardUserDefaults] setObject:theme.identifier forKey:GQSelectedThemeDefaultsKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self applyCurrentTheme];
	[self.themePopover close];
	self.themePopover = nil;
}

- (NSUInteger)interfaceVersion {
	return 1;
}

- (NSString *)title {
	return GQLocalized(@"Glyph Quest", @"グリフクエスト", @"Glyph Quest", @"글리프 퀘스트");
}

- (NSUInteger)sortID {
	return 15;
}

- (NSInteger)minHeight {
	return (NSInteger)ceil(GQPaletteHeight);
}

- (NSInteger)maxHeight {
	return (NSInteger)ceil(GQPaletteHeight);
}

- (NSUInteger)currentHeight {
	return self.paletteCurrentHeight;
}

- (void)setCurrentHeight:(NSUInteger)newHeight {
	NSUInteger clamped = MIN((NSUInteger)self.maxHeight, MAX((NSUInteger)self.minHeight, newHeight));
	_paletteCurrentHeight = clamped;
}

- (NSView *)theView {
	return self.view;
}

- (void)loadPlugin {
	[self startObserving];
	[self updateDisplay];
}

- (void)startObserving {
	if (self.observing) {
		return;
	}
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(glyphsInterfaceDidUpdate:) name:@"GSUpdateInterface" object:nil];
	[center addObserver:self selector:@selector(glyphsInterfaceDidUpdate:) name:@"GSDocumentActivateNotification" object:nil];
	self.observing = YES;
}

- (void)glyphsInterfaceDidUpdate:(NSNotification *)notification {
	(void)notification;
	[self updateDisplay];
}

- (void)modeChanged:(id)sender {
	(void)sender;
	[self.panelView updateModeVisibility];
}

- (void)updatePaletteHeight {
	NSUInteger height = (NSUInteger)ceil(GQPaletteHeight);
	CGFloat width = NSWidth(self.view.frame) > 1.0 ? NSWidth(self.view.frame) : GQPaletteWidth;
	if (self.paletteCurrentHeight != height) {
		[self willChangeValueForKey:@"currentHeight"];
		_paletteCurrentHeight = height;
		[self didChangeValueForKey:@"currentHeight"];
	}
	[self.view setFrameSize:NSMakeSize(width, (CGFloat)height)];
	[self.view setNeedsLayout:YES];
	[self.panelView layoutPanel];
}

- (GSFont *)currentFont {
	if ([self.windowController respondsToSelector:@selector(documentFont)]) {
		GSFont *font = self.windowController.documentFont;
		if (font) {
			return font;
		}
	}

	id document = nil;
	if ([self.windowController respondsToSelector:@selector(document)]) {
		document = [(NSWindowController *)self.windowController document];
	}
	if (document && [document respondsToSelector:@selector(font)]) {
		return [(id<GlyphQuestFontDocument>)document font];
	}

	if ([NSApp respondsToSelector:@selector(currentFontDocument)]) {
		id currentDocument = [(id<GlyphQuestGlyphsApplication>)NSApp currentFontDocument];
		if (currentDocument && [currentDocument respondsToSelector:@selector(font)]) {
			return [(id<GlyphQuestFontDocument>)currentDocument font];
		}
	}
	return nil;
}

- (BOOL)isEligibleGlyph:(GSGlyph *)glyph masters:(NSArray<GSFontMaster *> *)masters {
	if (!glyph.export) {
		return NO;
	}
	if ([glyph.name hasPrefix:@"_part."]) {
		return NO;
	}
	for (GSFontMaster *master in masters) {
		GSLayer *layer = [glyph layerForId:master.id];
		if (layer.isSmartComponentLayer) {
			return NO;
		}
	}
	return YES;
}

- (BOOL)layerHasShapesForGlyph:(GSGlyph *)glyph master:(GSFontMaster *)master {
	GSLayer *layer = [glyph layerForId:master.id];
	if (!layer) {
		return NO;
	}
	return layer.shapes.count > 0;
}

- (CGFloat)glyphScore:(GSGlyph *)glyph masters:(NSArray<GSFontMaster *> *)masters {
	if (masters.count == 0) {
		return 0.0;
	}
	NSUInteger drawn = 0;
	for (GSFontMaster *master in masters) {
		if ([self layerHasShapesForGlyph:glyph master:master]) {
			drawn++;
		}
	}
	if (drawn == masters.count) {
		return 1.0;
	}
	return round(((CGFloat)drawn / (CGFloat)masters.count) * 100.0) / 100.0;
}

- (GlyphQuestProgressResult *)calculateProgressForFont:(GSFont *)font {
	if (!font) {
		return nil;
	}

	GlyphQuestProgressResult *result = [[GlyphQuestProgressResult alloc] init];
	NSArray<GSFontMaster *> *masters = font.fontMasters ?: @[];
	if (masters.count == 0) {
		result.scriptStats = @[];
		return result;
	}

	NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSNumber *> *> *scriptBuckets = [NSMutableDictionary dictionary];
	CGFloat scoreSum = 0.0;
	NSUInteger totalCount = 0;

	for (GSGlyph *glyph in font.glyphs) {
		if (![self isEligibleGlyph:glyph masters:masters]) {
			continue;
		}
		CGFloat score = [self glyphScore:glyph masters:masters];
		scoreSum += score;
		totalCount++;

		NSString *scriptID = glyph.script.length > 0 ? glyph.script : @"unknown";
		NSMutableDictionary<NSString *, NSNumber *> *bucket = scriptBuckets[scriptID];
		if (!bucket) {
			bucket = [@{@"score": @0.0, @"count": @0} mutableCopy];
			scriptBuckets[scriptID] = bucket;
		}
		bucket[@"score"] = @([bucket[@"score"] doubleValue] + score);
		bucket[@"count"] = @([bucket[@"count"] unsignedIntegerValue] + 1);
	}

	result.scoreSum = scoreSum;
	result.totalCount = totalCount;
	result.percent = totalCount > 0 ? round((scoreSum / (CGFloat)totalCount) * 1000.0) / 10.0 : 0.0;

	NSArray<NSString *> *scriptIDs = [scriptBuckets.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
		return [GQScriptLabelForID(left) localizedCaseInsensitiveCompare:GQScriptLabelForID(right)];
	}];

	NSMutableArray<GQScriptStat *> *stats = [NSMutableArray array];
	for (NSString *scriptID in scriptIDs) {
		NSDictionary<NSString *, NSNumber *> *bucket = scriptBuckets[scriptID];
		NSUInteger count = [bucket[@"count"] unsignedIntegerValue];
		CGFloat scriptScore = [bucket[@"score"] doubleValue];

		GQScriptStat *stat = [[GQScriptStat alloc] init];
		stat.scriptID = scriptID;
		stat.scoreSum = scriptScore;
		stat.total = count;
		stat.percent = count > 0 ? round((scriptScore / (CGFloat)count) * 1000.0) / 10.0 : 0.0;
		[stats addObject:stat];
	}
	result.scriptStats = stats;
	return result;
}

- (void)updateDisplay {
	(void)self.view;
	GlyphQuestProgressResult *result = [self calculateProgressForFont:[self currentFont]];
	if (!result) {
		[self.panelView setOverviewUnavailable];
		[self updatePaletteHeight];
		return;
	}

	[self.panelView setOverviewProgress:result.percent scoreSum:result.scoreSum totalCount:result.totalCount];
	[self.panelView updateScriptRowsWithStats:result.scriptStats];
	[self updatePaletteHeight];
}

@end
