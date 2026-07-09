//
//  GlyphQuestPalette.m
//  GlyphQuest
//
//  Native Glyphs palette plugin.
//

#import "GlyphQuestPalette.h"
#import "GQThemeSpec.h"

#import <math.h>
#import <GlyphsCore/GSFont.h>
#import <GlyphsCore/GSFontMaster.h>
#import <GlyphsCore/GSGlyph.h>
#import <GlyphsCore/GSLayer.h>
#import <GlyphsCore/GSPaletteView.h>
#import <GlyphsCore/GSWindowControllerProtocol.h>
#import <CoreText/CoreText.h>

@protocol GlyphQuestFontDocument <NSObject>
- (GSFont *)font;
@end

@protocol GlyphQuestGlyphsApplication <NSObject>
- (id)currentFontDocument;
@end

static const CGFloat GQPaletteWidth = 250.0;
static const CGFloat GQPaletteHeight = 190.0;
static const CGFloat GQCardMarginH = 14.0;
static const CGFloat GQCardMarginV = 16.0;
static const CGFloat GQCardLeftCap = 135.0;
static const CGFloat GQCardRightCap = 118.0;
static const CGFloat GQScriptRowHeight = 24.0;
static const CGFloat GQScriptBarHeight = 7.0;
static const NSUInteger GQMaxScriptRows = 48;

static NSString *GQLanguageKey(void) {
	NSArray<NSString *> *languages = NSLocale.preferredLanguages;
	NSString *language = languages.count > 0 ? languages.firstObject : @"";
	if ([language hasPrefix:@"ja"]) {
		return @"ja";
	}
	if ([language hasPrefix:@"zh"]) {
		return @"zh";
	}
	if ([language hasPrefix:@"ko"]) {
		return @"ko";
	}
	return @"en";
}

static NSString *GQLocalized(NSString *english, NSString *japanese, NSString *chinese, NSString *korean) {
	NSString *key = GQLanguageKey();
	if ([key isEqualToString:@"ja"]) {
		return japanese;
	}
	if ([key isEqualToString:@"zh"]) {
		return chinese;
	}
	if ([key isEqualToString:@"ko"]) {
		return korean;
	}
	return english;
}

static NSColor *GQColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
	return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}

static void GQRegisterBundledFonts(NSBundle *bundle) {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSArray<NSString *> *fontResourceNames = @[
			@"Quicksand-Bold",
			@"Orbitron-Black",
			@"Cinzel-Black",
			@"Nunito-ExtraBold",
			@"Exo2-ExtraBold",
		];
		for (NSString *fontResourceName in fontResourceNames) {
			NSURL *fontURL = [bundle URLForResource:fontResourceName withExtension:@"ttf" subdirectory:@"Fonts"];
			if (!fontURL) {
				continue;
			}
			CFErrorRef error = NULL;
			CTFontManagerRegisterFontsForURL((__bridge CFURLRef)fontURL, kCTFontManagerScopeProcess, &error);
			if (error) {
				CFRelease(error);
			}
		}
	});
}

static NSFont *GQFontNamed(NSString *fontName, CGFloat size) {
	NSFont *font = [NSFont fontWithName:fontName size:size];
	if (!font) {
		font = [NSFont fontWithName:[fontName stringByReplacingOccurrencesOfString:@"-" withString:@" "] size:size];
	}
	if (!font) {
		font = [NSFont systemFontOfSize:size weight:NSFontWeightBold];
	}
	return font;
}

static void GQDrawImagePart(NSImage *image, NSRect destination, NSRect source) {
	[image drawInRect:destination
			 fromRect:source
			operation:NSCompositingOperationSourceOver
			 fraction:1.0
	   respectFlipped:YES
				hints:@{NSImageHintInterpolation: @(NSImageInterpolationHigh)}];
}

static void GQDrawHorizontallyResizableImage(NSImage *image, NSRect destination, CGFloat leftCap, CGFloat rightCap) {
	CGSize imageSize = image.size;
	if (imageSize.width <= 0.0 || imageSize.height <= 0.0 || NSWidth(destination) <= 0.0 || NSHeight(destination) <= 0.0) {
		return;
	}

	leftCap = fmax(0.0, fmin(leftCap, imageSize.width));
	rightCap = fmax(0.0, fmin(rightCap, imageSize.width - leftCap));

	CGFloat verticalScale = NSHeight(destination) / imageSize.height;
	CGFloat leftWidth = leftCap * verticalScale;
	CGFloat rightWidth = rightCap * verticalScale;
	CGFloat available = NSWidth(destination);
	if (leftWidth + rightWidth > available) {
		CGFloat ratio = available / fmax(1.0, leftWidth + rightWidth);
		leftWidth *= ratio;
		rightWidth *= ratio;
	}

	CGFloat seamOverlap = 1.0 / fmax(1.0, [[NSScreen mainScreen] backingScaleFactor]);

	NSRect leftSource = NSMakeRect(0.0, 0.0, leftCap, imageSize.height);
	NSRect centerSource = NSMakeRect(leftCap, 0.0, imageSize.width - leftCap - rightCap, imageSize.height);
	NSRect rightSource = NSMakeRect(imageSize.width - rightCap, 0.0, rightCap, imageSize.height);

	NSRect leftDestination = NSMakeRect(NSMinX(destination), NSMinY(destination), leftWidth, NSHeight(destination));
	NSRect rightDestination = NSMakeRect(NSMaxX(destination) - rightWidth, NSMinY(destination), rightWidth, NSHeight(destination));
	NSRect centerDestination = NSMakeRect(NSMaxX(leftDestination) - seamOverlap,
										  NSMinY(destination),
										  NSMinX(rightDestination) - NSMaxX(leftDestination) + seamOverlap * 2.0,
										  NSHeight(destination));

	GQDrawImagePart(image, leftDestination, leftSource);
	if (NSWidth(centerDestination) > 0.0 && NSWidth(centerSource) > 0.0) {
		GQDrawImagePart(image, centerDestination, centerSource);
	}
	GQDrawImagePart(image, rightDestination, rightSource);
}

static NSRect GQResolvedSourceRect(NSImage *image, NSRect requestedSource) {
	NSRect fullSource = NSMakeRect(0.0, 0.0, image.size.width, image.size.height);
	if (NSIsEmptyRect(requestedSource)) {
		return fullSource;
	}
	return NSIntersectionRect(fullSource, requestedSource);
}

// Preserve the rich generated end caps while repeating only a deliberately quiet
// vertical strip in the middle. This keeps the card intact at every sidebar width.
static void GQDrawHorizontallyTiledCard(NSImage *image,
										 NSRect requestedSource,
										 NSRect destination,
										 CGFloat leftCap,
										 CGFloat rightCap,
										 CGFloat tileX,
										 CGFloat tileWidth) {
	if (!image || NSWidth(destination) <= 0.0 || NSHeight(destination) <= 0.0) {
		return;
	}

	NSRect source = GQResolvedSourceRect(image, requestedSource);
	if (NSIsEmptyRect(source)) {
		return;
	}

	leftCap = fmax(0.0, fmin(leftCap, NSWidth(source)));
	rightCap = fmax(0.0, fmin(rightCap, NSWidth(source) - leftCap));
	CGFloat verticalScale = NSHeight(destination) / NSHeight(source);
	CGFloat leftWidth = leftCap * verticalScale;
	CGFloat rightWidth = rightCap * verticalScale;
	if (leftWidth + rightWidth > NSWidth(destination)) {
		CGFloat ratio = NSWidth(destination) / fmax(1.0, leftWidth + rightWidth);
		leftWidth *= ratio;
		rightWidth *= ratio;
	}

	NSRect leftSource = NSMakeRect(NSMinX(source), NSMinY(source), leftCap, NSHeight(source));
	NSRect rightSource = NSMakeRect(NSMaxX(source) - rightCap, NSMinY(source), rightCap, NSHeight(source));
	NSRect leftDestination = NSMakeRect(NSMinX(destination), NSMinY(destination), leftWidth, NSHeight(destination));
	NSRect rightDestination = NSMakeRect(NSMaxX(destination) - rightWidth, NSMinY(destination), rightWidth, NSHeight(destination));
	GQDrawImagePart(image, leftDestination, leftSource);
	GQDrawImagePart(image, rightDestination, rightSource);

	NSRect centerDestination = NSMakeRect(NSMaxX(leftDestination), NSMinY(destination),
										NSMinX(rightDestination) - NSMaxX(leftDestination), NSHeight(destination));
	if (NSWidth(centerDestination) <= 0.0) {
		return;
	}

	tileWidth = fmax(1.0, fmin(tileWidth, NSWidth(source) - leftCap - rightCap));
	tileX = fmax(leftCap, fmin(tileX, NSWidth(source) - rightCap - tileWidth));
	NSRect tileSource = NSMakeRect(NSMinX(source) + tileX, NSMinY(source), tileWidth, NSHeight(source));
	CGFloat tileDestinationWidth = fmax(1.0, tileWidth * verticalScale);
	CGFloat seamOverlap = 1.0 / fmax(1.0, [[NSScreen mainScreen] backingScaleFactor]);

	[NSGraphicsContext saveGraphicsState];
	[[NSBezierPath bezierPathWithRect:centerDestination] addClip];
	for (CGFloat x = NSMinX(centerDestination); x < NSMaxX(centerDestination); x += tileDestinationWidth) {
		NSRect tileDestination = NSMakeRect(x - seamOverlap, NSMinY(centerDestination),
										 tileDestinationWidth + seamOverlap * 2.0, NSHeight(centerDestination));
		GQDrawImagePart(image, tileDestination, tileSource);
	}
	[NSGraphicsContext restoreGraphicsState];
}

static void GQDrawAspectFillImage(NSImage *image, NSRect destination) {
	CGSize imageSize = image.size;
	if (imageSize.width <= 0.0 || imageSize.height <= 0.0 || NSWidth(destination) <= 0.0 || NSHeight(destination) <= 0.0) {
		return;
	}

	CGFloat destinationAspect = NSWidth(destination) / NSHeight(destination);
	CGFloat sourceAspect = imageSize.width / imageSize.height;
	NSRect source = NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height);
	if (sourceAspect > destinationAspect) {
		CGFloat sourceWidth = imageSize.height * destinationAspect;
		source.origin.x = (imageSize.width - sourceWidth) / 2.0;
		source.size.width = sourceWidth;
	} else if (sourceAspect < destinationAspect) {
		CGFloat sourceHeight = imageSize.width / destinationAspect;
		source.origin.y = (imageSize.height - sourceHeight) / 2.0;
		source.size.height = sourceHeight;
	}
	GQDrawImagePart(image, destination, source);
}

static NSRect GQCardFrame(NSRect bounds) {
	return NSInsetRect(bounds, GQCardMarginH, GQCardMarginV);
}

static NSString *GQGlyphUnit(void) {
	return GQLocalized(@"Glyphs", @"Glyph", @"字形", @"글리프");
}

static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *GQScriptLabels(void) {
	static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *labels;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		labels = @{
			@"latin": @{@"en": @"Latin", @"ja": @"ラテン", @"zh": @"拉丁", @"ko": @"라틴"},
			@"han": @{@"en": @"Han", @"ja": @"漢字", @"zh": @"汉字", @"ko": @"한자"},
			@"kana": @{@"en": @"Kana", @"ja": @"かな", @"zh": @"假名", @"ko": @"가나"},
			@"hang": @{@"en": @"Hangul", @"ja": @"ハングル", @"zh": @"韩文", @"ko": @"한글"},
			@"cyrl": @{@"en": @"Cyrillic", @"ja": @"キリル", @"zh": @"西里尔", @"ko": @"키릴"},
			@"grek": @{@"en": @"Greek", @"ja": @"ギリシャ", @"zh": @"希腊", @"ko": @"그리스"},
			@"arab": @{@"en": @"Arabic", @"ja": @"アラビア", @"zh": @"阿拉伯", @"ko": @"아랍"},
			@"hebr": @{@"en": @"Hebrew", @"ja": @"ヘブライ", @"zh": @"希伯来", @"ko": @"히브리"},
			@"deva": @{@"en": @"Devanagari", @"ja": @"デーヴァナーガリー", @"zh": @"天城文", @"ko": @"데바나가리"},
			@"thai": @{@"en": @"Thai", @"ja": @"タイ", @"zh": @"泰文", @"ko": @"태국"},
			@"beng": @{@"en": @"Bengali", @"ja": @"ベンガル", @"zh": @"孟加拉", @"ko": @"벵골"},
			@"guru": @{@"en": @"Gurmukhi", @"ja": @"グルムキー", @"zh": @"古鲁穆奇", @"ko": @"구르무키"},
			@"gujr": @{@"en": @"Gujarati", @"ja": @"グジャラート", @"zh": @"古吉拉特", @"ko": @"구자라트"},
			@"taml": @{@"en": @"Tamil", @"ja": @"タミル", @"zh": @"泰米尔", @"ko": @"타밀"},
			@"telu": @{@"en": @"Telugu", @"ja": @"テルグ", @"zh": @"泰卢固", @"ko": @"텔루구"},
			@"knda": @{@"en": @"Kannada", @"ja": @"カンナダ", @"zh": @"卡纳达", @"ko": @"칸나다"},
			@"mlym": @{@"en": @"Malayalam", @"ja": @"マラヤーラム", @"zh": @"马拉雅拉姆", @"ko": @"말라얄람"},
			@"sinh": @{@"en": @"Sinhala", @"ja": @"シンハラ", @"zh": @"僧伽罗", @"ko": @"신할라"},
			@"mymr": @{@"en": @"Myanmar", @"ja": @"ミャンマー", @"zh": @"缅甸", @"ko": @"미얀마"},
			@"khmr": @{@"en": @"Khmer", @"ja": @"クメール", @"zh": @"高棉", @"ko": @"크메르"},
			@"laoo": @{@"en": @"Lao", @"ja": @"ラオ", @"zh": @"老挝", @"ko": @"라오"},
			@"tibt": @{@"en": @"Tibetan", @"ja": @"チベット", @"zh": @"藏文", @"ko": @"티베트"},
			@"geor": @{@"en": @"Georgian", @"ja": @"グルジア", @"zh": @"格鲁吉亚", @"ko": @"조지아"},
			@"armn": @{@"en": @"Armenian", @"ja": @"アルメニア", @"zh": @"亚美尼亚", @"ko": @"아르메니아"},
			@"ethi": @{@"en": @"Ethiopic", @"ja": @"エチオピア", @"zh": @"埃塞俄比亚", @"ko": @"에티오피아"},
			@"cher": @{@"en": @"Cherokee", @"ja": @"チェロキー", @"zh": @"切罗基", @"ko": @"체로키"},
			@"runr": @{@"en": @"Runic", @"ja": @"ルーン", @"zh": @"卢恩", @"ko": @"룬"},
			@"ogam": @{@"en": @"Ogham", @"ja": @"オガム", @"zh": @"欧甘", @"ko": @"오검"},
			@"syrc": @{@"en": @"Syriac", @"ja": @"シリア", @"zh": @"叙利亚", @"ko": @"시리아"},
			@"thaa": @{@"en": @"Thaana", @"ja": @"ターナ", @"zh": @"塔安那", @"ko": @"타나"},
			@"orya": @{@"en": @"Oriya", @"ja": @"オリヤー", @"zh": @"奥里亚", @"ko": @"오리야"},
			@"goth": @{@"en": @"Gothic", @"ja": @"ゴシック", @"zh": @"哥特", @"ko": @"고트"},
			@"linb": @{@"en": @"Linear B", @"ja": @"線文字B", @"zh": @"线形文字B", @"ko": @"선형문자 B"},
			@"copt": @{@"en": @"Coptic", @"ja": @"コプト", @"zh": @"科普特", @"ko": @"콥트"},
			@"yiii": @{@"en": @"Yi", @"ja": @"イ", @"zh": @"彝文", @"ko": @"이"},
			@"tglg": @{@"en": @"Tagalog", @"ja": @"タガログ", @"zh": @"他加禄", @"ko": @"타갈로그"},
			@"hano": @{@"en": @"Hanunoo", @"ja": @"ハヌノオ", @"zh": @"哈努诺", @"ko": @"하누노"},
			@"buhd": @{@"en": @"Buhid", @"ja": @"ブヒッド", @"zh": @"布希德", @"ko": @"부히드"},
			@"tagb": @{@"en": @"Tagbanwa", @"ja": @"タグバンワ", @"zh": @"塔格班瓦", @"ko": @"타그반와"},
			@"limb": @{@"en": @"Limbu", @"ja": @"リンブ", @"zh": @"林布", @"ko": @"림부"},
			@"tale": @{@"en": @"Tai Le", @"ja": @"タイ・レ", @"zh": @"傣仂", @"ko": @"타이레"},
		};
	});
	return labels;
}

@interface GlyphQuestRootView : GSPaletteView
@property (nonatomic, strong) GQThemeSpec *theme;
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
	[super drawRect:dirtyRect];

	NSRect bounds = self.bounds;
	GQThemeSpec *theme = self.theme ?: GQThemeForIdentifier(nil);
	NSBundle *bundle = [NSBundle bundleForClass:self.class];
	NSImage *sceneImage = [theme imageNamed:@"scene" inBundle:bundle];
	NSImage *cardImage = [theme imageNamed:@"card" inBundle:bundle];

	if (sceneImage || cardImage) {
		if (sceneImage) {
			GQDrawAspectFillImage(sceneImage, bounds);
		}
		if (cardImage) {
			if (theme.usesTiledCardCenter) {
				GQDrawHorizontallyTiledCard(cardImage,
											theme.cardSourceRect,
											GQCardFrame(bounds),
											theme.cardLeftCap,
											theme.cardRightCap,
											theme.cardCenterTileX,
											theme.cardCenterTileWidth);
			} else {
				GQDrawHorizontallyResizableImage(cardImage, GQCardFrame(bounds), theme.cardLeftCap, theme.cardRightCap);
			}
		}
		return;
	}

	NSGradient *background = [[NSGradient alloc] initWithColors:@[
		GQColor(0.80, 0.93, 0.98, 1.0),
		GQColor(0.93, 0.98, 0.92, 1.0),
	]];
	[background drawInRect:bounds angle:-90.0];

	NSRect inset = NSInsetRect(bounds, 7.0, 7.0);
	NSBezierPath *panel = [NSBezierPath bezierPathWithRoundedRect:inset xRadius:8.0 yRadius:8.0];

	NSShadow *shadow = [[NSShadow alloc] init];
	shadow.shadowColor = GQColor(0.14, 0.20, 0.20, 0.18);
	shadow.shadowBlurRadius = 3.0;
	shadow.shadowOffset = NSMakeSize(0.0, -1.0);
	[NSGraphicsContext saveGraphicsState];
	[shadow set];
	[GQColor(0.96, 0.98, 0.95, 1.0) setFill];
	[panel fill];
	[NSGraphicsContext restoreGraphicsState];

	NSGradient *panelGradient = [[NSGradient alloc] initWithColors:@[
		GQColor(0.995, 0.995, 0.990, 1.0),
		GQColor(0.940, 0.980, 0.940, 1.0),
	]];
	[panelGradient drawInBezierPath:panel angle:-90.0];

	[GQColor(0.35, 0.72, 0.68, 0.60) setStroke];
	panel.lineWidth = 1.0;
	[panel stroke];

	for (NSUInteger corner = 0; corner < 4; corner++) {
		CGFloat x = (corner % 2 == 0) ? NSMinX(inset) + 7.0 : NSMaxX(inset) - 11.0;
		CGFloat y = (corner < 2) ? NSMinY(inset) + 7.0 : NSMaxY(inset) - 11.0;
		NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x, y, 4.0, 4.0)];
		[GQColor(0.36, 0.68, 0.63, 0.38) setFill];
		[dot fill];
	}
}
@end

@interface GlyphQuestProgressView : NSView
@property (nonatomic) CGFloat progress;
@property (nonatomic) BOOL large;
@property (nonatomic, strong) GQThemeSpec *theme;
@end

@implementation GlyphQuestProgressView

- (BOOL)isOpaque {
	return NO;
}

- (void)setProgress:(CGFloat)progress {
	CGFloat clamped = fmax(0.0, fmin(100.0, progress));
	if (fabs(_progress - clamped) < 0.05) {
		return;
	}
	_progress = clamped;
	self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
	GQThemeSpec *theme = self.theme ?: GQThemeForIdentifier(nil);
	[GQProgressRenderer drawProgressInRect:self.bounds
								  progress:self.progress
									 large:self.large
									 theme:theme
									bundle:[NSBundle bundleForClass:self.class]];
}

@end

@interface GlyphQuestScriptRowView : NSView
@property (nonatomic, strong) NSTextField *nameLabel;
@property (nonatomic, strong) NSTextField *percentLabel;
@property (nonatomic, strong) GlyphQuestProgressView *progressBar;
@property (nonatomic, strong) GQThemeSpec *theme;
- (void)updateWithName:(NSString *)name percentText:(NSString *)percentText progress:(CGFloat)progress;
@end

@implementation GlyphQuestScriptRowView

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	if (self) {
		_nameLabel = [NSTextField labelWithString:@""];
		_nameLabel.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];

		_percentLabel = [NSTextField labelWithString:@""];
		_percentLabel.font = [NSFont monospacedDigitSystemFontOfSize:10.5 weight:NSFontWeightMedium];
		_percentLabel.alignment = NSTextAlignmentRight;

		_progressBar = [[GlyphQuestProgressView alloc] initWithFrame:NSZeroRect];

		[self addSubview:_nameLabel];
		[self addSubview:_percentLabel];
		[self addSubview:_progressBar];
		self.theme = GQThemeForIdentifier(nil);
	}
	return self;
}

- (BOOL)isFlipped {
	return YES;
}

- (void)layout {
	[super layout];
	CGFloat width = NSWidth(self.bounds);
	CGFloat horizontalInset = 10.0;
	self.nameLabel.frame = NSMakeRect(horizontalInset, 0.0, fmax(0.0, width - horizontalInset - 58.0), 12.0);
	self.percentLabel.frame = NSMakeRect(fmax(0.0, width - 52.0), 0.0, 44.0, 12.0);
	self.progressBar.frame = NSMakeRect(horizontalInset, 13.0, fmax(0.0, width - horizontalInset * 2.0), GQScriptBarHeight);
}

- (void)updateWithName:(NSString *)name percentText:(NSString *)percentText progress:(CGFloat)progress {
	self.nameLabel.stringValue = name ?: @"";
	self.percentLabel.stringValue = percentText ?: @"";
	self.progressBar.progress = progress;
	self.needsDisplay = YES;
}

- (void)setTheme:(GQThemeSpec *)theme {
	_theme = theme ?: GQThemeForIdentifier(nil);
	self.nameLabel.textColor = _theme.rowTextColor;
	self.percentLabel.textColor = _theme.rowPercentColor;
	self.progressBar.theme = _theme;
	self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];

	GQThemeSpec *theme = self.theme ?: GQThemeForIdentifier(nil);
	NSRect rowRect = NSInsetRect(self.bounds, 1.0, 1.0);
	NSBezierPath *rowPath = [NSBezierPath bezierPathWithRoundedRect:rowRect xRadius:6.0 yRadius:6.0];
	NSGradient *rowGradient = [[NSGradient alloc] initWithColors:@[
		theme.rowTopColor,
		theme.rowBottomColor,
	]];
	[rowGradient drawInBezierPath:rowPath angle:-90.0];

	[theme.rowStrokeColor setStroke];
	rowPath.lineWidth = 0.75;
	[rowPath stroke];

	CGFloat accentHeight = fmax(5.0, NSHeight(rowRect) - 8.0);
	NSRect accentRect = NSMakeRect(NSMinX(rowRect) + 2.0, NSMinY(rowRect) + 4.0, 3.0, accentHeight);
	NSBezierPath *accent = [NSBezierPath bezierPathWithRoundedRect:accentRect xRadius:1.5 yRadius:1.5];
	[theme.rowAccentColor setFill];
	[accent fill];
}

@end

@interface GlyphQuestScriptListView : NSView
@end

@implementation GlyphQuestScriptListView
- (BOOL)isFlipped {
	return YES;
}
@end

@interface GlyphQuestToggleButton : NSButton
@property (nonatomic, strong) GQThemeSpec *theme;
@end

@implementation GlyphQuestToggleButton

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	if (self) {
		self.bordered = NO;
		self.buttonType = NSButtonTypeToggle;
		self.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightBold];
		self.alignment = NSTextAlignmentCenter;
		self.lineBreakMode = NSLineBreakByTruncatingTail;
		// Keep AppKit from compositing the artwork through the sidebar vibrancy filter.
		[[self cell] setHighlightsBy:NSNoCellMask];
		[[self cell] setShowsStateBy:NSNoCellMask];
	}
	return self;
}

- (BOOL)isOpaque {
	return NO;
}

- (BOOL)allowsVibrancy {
	return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
	(void)event;
	return YES;
}

- (void)setTheme:(GQThemeSpec *)theme {
	_theme = theme ?: GQThemeForIdentifier(nil);
	self.needsDisplay = YES;
}

- (void)setState:(NSControlStateValue)state {
	[super setState:state];
	self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	(void)dirtyRect;
	NSRect bounds = self.bounds;
	BOOL on = self.state == NSControlStateValueOn;
	GQThemeSpec *theme = self.theme ?: GQThemeForIdentifier(nil);
	NSBundle *bundle = [NSBundle bundleForClass:self.class];
	NSImage *offImage = [theme imageNamed:@"toggle-off" inBundle:bundle];
	NSImage *onImage = [theme imageNamed:@"toggle-on" inBundle:bundle];
	NSImage *image = on ? onImage : offImage;

	if (image) {
		image.template = NO;
		NSRect source = GQResolvedSourceRect(image, theme.toggleSourceRect);
		// Copy keeps the bitmap out of the sidebar vibrancy filter that was crushing Cyber to black.
		[image drawInRect:bounds
				 fromRect:source
				operation:NSCompositingOperationCopy
				 fraction:1.0
		   respectFlipped:YES
					hints:@{NSImageHintInterpolation: @(NSImageInterpolationHigh)}];
	} else {
		NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:NSHeight(bounds) / 2.0 yRadius:NSHeight(bounds) / 2.0];
		[on ? GQColor(0.50, 0.80, 0.23, 1.0) : GQColor(0.98, 0.78, 0.33, 1.0) setFill];
		[body fill];
	}

	NSColor *textColor = theme.toggleTextColor ?: NSColor.whiteColor;
	NSShadow *textShadow = [[NSShadow alloc] init];
	textShadow.shadowColor = theme.toggleShadowColor ?: GQColor(0.05, 0.05, 0.05, 0.70);
	textShadow.shadowBlurRadius = 1.0;
	textShadow.shadowOffset = NSMakeSize(0.0, -1.0);
	NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
	paragraph.alignment = NSTextAlignmentCenter;
	paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
	NSDictionary *attributes = @{
		NSFontAttributeName: self.font,
		NSForegroundColorAttributeName: textColor,
		NSParagraphStyleAttributeName: paragraph,
		NSShadowAttributeName: textShadow,
	};
	NSSize textSize = [self.title sizeWithAttributes:attributes];
	CGFloat textX = NSMinX(bounds) + floor((NSWidth(bounds) - textSize.width) * 0.5);
	CGFloat textY = NSMinY(bounds) + floor((NSHeight(bounds) - textSize.height) * 0.5) - 0.5;
	[self.title drawAtPoint:NSMakePoint(textX, textY) withAttributes:attributes];
}

@end

@interface GlyphQuestSettingsButton : NSButton
@property (nonatomic, strong) GQThemeSpec *theme;
@end

@implementation GlyphQuestSettingsButton

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	if (self) {
		self.bordered = NO;
		self.buttonType = NSButtonTypeMomentaryChange;
		self.title = @"";
		[[self cell] setHighlightsBy:NSNoCellMask];
		[[self cell] setShowsStateBy:NSNoCellMask];
	}
	return self;
}

- (BOOL)isOpaque {
	return NO;
}

- (BOOL)allowsVibrancy {
	return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
	(void)event;
	return YES;
}

- (void)setTheme:(GQThemeSpec *)theme {
	_theme = theme ?: GQThemeForIdentifier(nil);
	self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	(void)dirtyRect;
	GQThemeSpec *theme = self.theme ?: GQThemeForIdentifier(nil);
	NSRect bounds = NSInsetRect(self.bounds, 0.75, 0.75);
	NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:5.5 yRadius:5.5];
	NSShadow *shadow = [[NSShadow alloc] init];
	shadow.shadowColor = theme.progressShadowColor ?: GQColor(0.0, 0.0, 0.0, 0.25);
	shadow.shadowBlurRadius = 1.8;
	shadow.shadowOffset = NSMakeSize(0.0, -1.0);
	[NSGraphicsContext saveGraphicsState];
	[shadow set];
	[theme.progressBezelBottomColor setFill];
	[body fill];
	[NSGraphicsContext restoreGraphicsState];

	NSGradient *gradient = [[NSGradient alloc] initWithColors:@[
		theme.progressBezelTopColor ?: GQColor(0.90, 0.90, 0.90, 1.0),
		theme.progressBezelBottomColor ?: GQColor(0.55, 0.55, 0.55, 1.0),
	]];
	[gradient drawInBezierPath:body angle:-90.0];

	[theme.progressBezelStrokeColor ?: GQColor(0.20, 0.20, 0.20, 0.55) setStroke];
	body.lineWidth = 1.0;
	[body stroke];

	NSPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
	NSBezierPath *gear = [NSBezierPath bezierPath];
	for (NSUInteger pointIndex = 0; pointIndex < 32; pointIndex++) {
		CGFloat angle = -M_PI_2 + (CGFloat)pointIndex * (M_PI * 2.0 / 32.0);
		CGFloat radius = (pointIndex % 4 < 2) ? 8.0 : 6.3;
		NSPoint point = NSMakePoint(center.x + cos(angle) * radius, center.y + sin(angle) * radius);
		if (pointIndex == 0) {
			[gear moveToPoint:point];
		} else {
			[gear lineToPoint:point];
		}
	}
	[gear closePath];
	[theme.settingsTextColor ?: NSColor.whiteColor setFill];
	[gear fill];

	NSBezierPath *hub = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - 3.0, center.y - 3.0, 6.0, 6.0)];
	[theme.progressBezelBottomColor ?: GQColor(0.20, 0.20, 0.20, 1.0) setFill];
	[hub fill];
}

@end

@interface GQThemePopoverView : NSView
@end

@implementation GQThemePopoverView

- (BOOL)isFlipped {
	return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	(void)dirtyRect;
	NSRect bounds = self.bounds;
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 0.5, 0.5) xRadius:8.0 yRadius:8.0];
	NSGradient *gradient = [[NSGradient alloc] initWithColors:@[
		GQColor(1.00, 0.98, 0.94, 1.0),
		GQColor(0.94, 0.95, 0.96, 1.0),
	]];
	[gradient drawInBezierPath:path angle:-90.0];
	[GQColor(0.47, 0.41, 0.34, 0.30) setStroke];
	path.lineWidth = 1.0;
	[path stroke];
}

@end

@interface GQThemeChoiceButton : NSButton
@property (nonatomic, strong) GQThemeSpec *themeSpec;
@property (nonatomic) BOOL selectedTheme;
@end

@implementation GQThemeChoiceButton

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	if (self) {
		self.bordered = NO;
		self.buttonType = NSButtonTypeMomentaryChange;
		self.alignment = NSTextAlignmentLeft;
		self.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold];
	}
	return self;
}

- (BOOL)isFlipped {
	return YES;
}

- (BOOL)isOpaque {
	return NO;
}

- (void)setThemeSpec:(GQThemeSpec *)themeSpec {
	_themeSpec = themeSpec;
	self.title = themeSpec.displayName ?: @"";
	self.needsDisplay = YES;
}

- (void)setSelectedTheme:(BOOL)selectedTheme {
	_selectedTheme = selectedTheme;
	self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	(void)dirtyRect;
	NSRect bounds = NSInsetRect(self.bounds, 2.0, 2.0);
	GQThemeSpec *theme = self.themeSpec ?: GQThemeForIdentifier(nil);
	BOOL highlighted = self.highlighted || self.selectedTheme;
	if (highlighted) {
		NSBezierPath *selectedPath = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:7.0 yRadius:7.0];
		NSColor *top = self.selectedTheme ? theme.rowTopColor : GQColor(1.0, 1.0, 1.0, 0.75);
		NSColor *bottom = self.selectedTheme ? theme.rowBottomColor : GQColor(0.86, 0.88, 0.90, 0.75);
		NSGradient *gradient = [[NSGradient alloc] initWithColors:@[top, bottom]];
		[gradient drawInBezierPath:selectedPath angle:-90.0];
		[theme.rowStrokeColor setStroke];
		selectedPath.lineWidth = 0.75;
		[selectedPath stroke];
	}

	NSRect swatchRect = NSMakeRect(NSMinX(bounds) + 8.0, NSMinY(bounds) + 7.0, 20.0, 12.0);
	NSBezierPath *swatch = [NSBezierPath bezierPathWithRoundedRect:swatchRect xRadius:6.0 yRadius:6.0];
	NSGradient *swatchGradient = [[NSGradient alloc] initWithColors:theme.progressFillColors ?: @[NSColor.systemBlueColor, NSColor.systemGreenColor]];
	[swatchGradient drawInBezierPath:swatch angle:0.0];
	[GQColor(1.0, 1.0, 1.0, 0.85) setStroke];
	swatch.lineWidth = 0.75;
	[swatch stroke];

	NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
	paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
	paragraph.alignment = NSTextAlignmentLeft;
	NSColor *textColor = self.selectedTheme ? theme.rowTextColor : NSColor.labelColor;
	NSDictionary *textAttributes = @{
		NSFontAttributeName: self.font,
		NSForegroundColorAttributeName: textColor,
		NSParagraphStyleAttributeName: paragraph,
	};
	NSRect textRect = NSMakeRect(NSMinX(bounds) + 36.0, NSMinY(bounds) + 5.0, NSWidth(bounds) - 62.0, 18.0);
	[self.title drawInRect:textRect withAttributes:textAttributes];

	if (self.selectedTheme) {
		NSDictionary *checkAttributes = @{
			NSFontAttributeName: [NSFont systemFontOfSize:13.0 weight:NSFontWeightHeavy],
			NSForegroundColorAttributeName: theme.rowPercentColor ?: NSColor.systemBlueColor,
		};
		NSString *check = @"✓";
		NSSize checkSize = [check sizeWithAttributes:checkAttributes];
		[check drawAtPoint:NSMakePoint(NSMaxX(bounds) - checkSize.width - 10.0,
									   NSMinY(bounds) + 4.5)
			withAttributes:checkAttributes];
	}
}

@end

@interface GlyphQuestScriptStat : NSObject
@property (nonatomic, copy) NSString *scriptID;
@property (nonatomic) CGFloat percent;
@property (nonatomic) CGFloat scoreSum;
@property (nonatomic) NSUInteger total;
@end

@implementation GlyphQuestScriptStat
@end

@interface GlyphQuestProgressResult : NSObject
@property (nonatomic) CGFloat percent;
@property (nonatomic) CGFloat scoreSum;
@property (nonatomic) NSUInteger totalCount;
@property (nonatomic, copy) NSArray<GlyphQuestScriptStat *> *scriptStats;
@end

@implementation GlyphQuestProgressResult
@end

@interface GlyphQuestPalette ()
@property (nonatomic, strong) GlyphQuestRootView *rootView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *progressLabel;
@property (nonatomic, strong) NSTextField *percentLabel;
@property (nonatomic, strong) NSTextField *countLabel;
@property (nonatomic, strong) GlyphQuestToggleButton *scriptToggleButton;
@property (nonatomic, strong) GlyphQuestSettingsButton *settingsButton;
@property (nonatomic, strong) NSPopover *themePopover;
@property (nonatomic, strong) GQThemeSpec *currentTheme;
@property (nonatomic, strong) NSScrollView *scriptScrollView;
@property (nonatomic, strong) GlyphQuestScriptListView *scriptContentView;
@property (nonatomic, strong) NSMutableArray<GlyphQuestScriptRowView *> *scriptRows;
@property (nonatomic) NSUInteger scriptRowCount;
@property (nonatomic) NSUInteger paletteCurrentHeight;
@property (nonatomic) BOOL observing;
@end

@implementation GlyphQuestPalette

@synthesize windowController = _windowController;

- (instancetype)init {
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_scriptRows = [NSMutableArray array];
		_scriptRowCount = 0;
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
	self.rootView.theme = self.currentTheme;
	self.view = self.rootView;
	[self buildInterface];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[self updateDisplay];
}

- (void)viewDidLayout {
	[super viewDidLayout];
	[self layoutPalette];
}

- (void)buildInterface {
	GQRegisterBundledFonts([NSBundle bundleForClass:self.class]);

	self.titleLabel = [NSTextField labelWithString:GQLocalized(@"Progress", @"進捗", @"进度", @"진행률")];
	self.titleLabel.font = [NSFont systemFontOfSize:12.5 weight:NSFontWeightHeavy];
	self.titleLabel.alignment = NSTextAlignmentLeft;

	self.progressLabel = [NSTextField labelWithString:GQLocalized(@"Progress", @"進捗", @"进度", @"진행률")];
	self.progressLabel.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold];
	self.progressLabel.alignment = NSTextAlignmentCenter;

	self.percentLabel = [NSTextField labelWithString:@"-"];
	self.percentLabel.font = GQFontNamed(self.currentTheme.percentFontName, 38.0);
	self.percentLabel.alignment = NSTextAlignmentCenter;

	self.countLabel = [NSTextField labelWithString:@""];
	self.countLabel.font = [NSFont monospacedDigitSystemFontOfSize:10.5 weight:NSFontWeightMedium];
	self.countLabel.alignment = NSTextAlignmentCenter;

	GlyphQuestProgressView *progressBar = [[GlyphQuestProgressView alloc] initWithFrame:NSZeroRect];
	progressBar.identifier = @"overallProgressBar";
	progressBar.large = YES;
	progressBar.theme = self.currentTheme;

	self.scriptToggleButton = [[GlyphQuestToggleButton alloc] initWithFrame:NSZeroRect];
	self.scriptToggleButton.title = GQLocalized(@"Scripts", @"文字体系別", @"文字体系", @"문자 체계별");
	self.scriptToggleButton.target = self;
	self.scriptToggleButton.action = @selector(modeChanged:);
	self.scriptToggleButton.state = NSControlStateValueOff;
	self.scriptToggleButton.theme = self.currentTheme;

	self.settingsButton = [[GlyphQuestSettingsButton alloc] initWithFrame:NSZeroRect];
	self.settingsButton.target = self;
	self.settingsButton.action = @selector(showThemePopover:);
	self.settingsButton.toolTip = GQLocalized(@"Theme", @"テーマ", @"主题", @"테마");
	self.settingsButton.theme = self.currentTheme;

	self.scriptContentView = [[GlyphQuestScriptListView alloc] initWithFrame:NSZeroRect];
	self.scriptScrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
	self.scriptScrollView.documentView = self.scriptContentView;
	self.scriptScrollView.drawsBackground = NO;
	self.scriptScrollView.borderType = NSNoBorder;
	self.scriptScrollView.hasVerticalScroller = YES;
	self.scriptScrollView.hasHorizontalScroller = NO;
	self.scriptScrollView.autohidesScrollers = YES;
	self.scriptScrollView.hidden = YES;

	[self.rootView addSubview:self.titleLabel];
	[self.rootView addSubview:self.progressLabel];
	[self.rootView addSubview:self.percentLabel];
	[self.rootView addSubview:progressBar];
	[self.rootView addSubview:self.countLabel];
	[self.rootView addSubview:self.scriptScrollView];

	for (NSUInteger index = 0; index < GQMaxScriptRows; index++) {
		GlyphQuestScriptRowView *row = [[GlyphQuestScriptRowView alloc] initWithFrame:NSZeroRect];
		row.hidden = YES;
		row.theme = self.currentTheme;
		[self.scriptContentView addSubview:row];
		[self.scriptRows addObject:row];
	}

	// Keep the controls above the list, including when the script scroll view is visible.
	// NSButton's built-in tracking covers the complete bounds, even where the artwork is transparent.
	[self.rootView addSubview:self.scriptToggleButton];
	[self.rootView addSubview:self.settingsButton];

	[self applyCurrentTheme];
	[self layoutPalette];
}

- (void)applyCurrentTheme {
	GQThemeSpec *theme = self.currentTheme ?: GQThemeForIdentifier(nil);
	self.currentTheme = theme;
	self.rootView.theme = theme;
	self.titleLabel.textColor = theme.titleColor;
	self.progressLabel.textColor = theme.progressTitleColor;
	self.percentLabel.font = GQFontNamed(theme.percentFontName, 38.0);
	self.percentLabel.textColor = theme.percentColor;
	self.countLabel.textColor = theme.countColor;
	self.scriptToggleButton.theme = theme;
	self.settingsButton.theme = theme;
	self.overallProgressBar.theme = theme;
	for (GlyphQuestScriptRowView *row in self.scriptRows) {
		row.theme = theme;
	}
	[self.rootView setNeedsDisplay:YES];
	[self.scriptToggleButton setNeedsDisplay:YES];
	[self.settingsButton setNeedsDisplay:YES];
	[self.overallProgressBar setNeedsDisplay:YES];
	[self.scriptContentView setNeedsDisplay:YES];
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
	[popover showRelativeToRect:self.settingsButton.bounds ofView:self.settingsButton preferredEdge:NSRectEdgeMaxY];
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

- (GlyphQuestProgressView *)overallProgressBar {
	for (NSView *subview in self.rootView.subviews) {
		if ([subview.identifier isEqualToString:@"overallProgressBar"] && [subview isKindOfClass:GlyphQuestProgressView.class]) {
			return (GlyphQuestProgressView *)subview;
		}
	}
	return nil;
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
	[self updateModeVisibility];
}

- (BOOL)isShowingScripts {
	return self.scriptToggleButton.state == NSControlStateValueOn;
}

- (void)updateModeVisibility {
	BOOL scripts = [self isShowingScripts];
	self.progressLabel.hidden = YES;
	self.percentLabel.hidden = scripts;
	self.overallProgressBar.hidden = scripts;
	self.countLabel.hidden = scripts;
	self.scriptScrollView.hidden = !scripts || self.scriptRowCount == 0;
	for (NSUInteger index = 0; index < self.scriptRows.count; index++) {
		GlyphQuestScriptRowView *row = self.scriptRows[index];
		row.hidden = !scripts || index >= self.scriptRowCount;
	}
	[self.view setNeedsDisplay:YES];
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
	[self layoutPalette];
}

- (void)layoutPalette {
	if (!self.rootView) {
		return;
	}

	CGFloat width = NSWidth(self.rootView.bounds) > 1.0 ? NSWidth(self.rootView.bounds) : GQPaletteWidth;
	CGFloat margin = 14.0;
	CGFloat toggleWidth = 94.0;
	CGFloat settingsSize = 26.0;
	CGFloat contentInset = fmin(42.0, fmax(30.0, width * 0.07));
	CGFloat offsetX = GQCardMarginH;
	CGFloat offsetY = GQCardMarginV;
	CGFloat titleLeading = self.currentTheme.titleLeading > 0.0 ? self.currentTheme.titleLeading : 56.0;

	self.titleLabel.frame = NSMakeRect(offsetX + titleLeading, offsetY + 17.0, fmax(0.0, width - offsetX - titleLeading - toggleWidth - 24.0 - offsetX), 18.0);
	self.scriptToggleButton.frame = NSMakeRect(width - offsetX - margin - toggleWidth, offsetY + 13.0, toggleWidth, 25.0);
	self.settingsButton.frame = NSMakeRect(fmax(offsetX + margin, width - offsetX - settingsSize - 9.0), GQPaletteHeight - offsetY - settingsSize - 9.0, settingsSize, settingsSize);

	self.progressLabel.frame = NSMakeRect(offsetX + margin, offsetY, width - (offsetX + margin) * 2.0, 0.0);
	self.percentLabel.frame = NSMakeRect(offsetX + margin, offsetY + 29.0, width - (offsetX + margin) * 2.0, 50.0);
	self.overallProgressBar.frame = NSMakeRect(contentInset, offsetY + 91.0, fmax(0.0, width - contentInset * 2.0), 22.0);
	self.countLabel.frame = NSMakeRect(offsetX + margin, offsetY + 120.0, width - (offsetX + margin) * 2.0, 16.0);

	CGFloat scrollY = offsetY + 44.0;
	CGFloat scrollHeight = GQPaletteHeight - scrollY - 28.0;
	CGFloat scrollInset = contentInset;
	self.scriptScrollView.frame = NSMakeRect(scrollInset, scrollY, width - scrollInset * 2.0, scrollHeight);
	self.scriptContentView.frame = NSMakeRect(0.0, 0.0, width - scrollInset * 2.0, self.scriptRowCount * GQScriptRowHeight);

	for (NSUInteger index = 0; index < self.scriptRows.count; index++) {
		GlyphQuestScriptRowView *row = self.scriptRows[index];
		row.frame = NSMakeRect(0.0, index * GQScriptRowHeight, width - scrollInset * 2.0, GQScriptRowHeight - 1.0);
		[row setNeedsLayout:YES];
	}
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

- (NSString *)scriptLabelForID:(NSString *)scriptID {
	NSString *normalizedID = scriptID.length > 0 ? scriptID : @"unknown";
	NSDictionary<NSString *, NSString *> *labels = GQScriptLabels()[normalizedID];
	if (labels) {
		return labels[GQLanguageKey()] ?: labels[@"en"];
	}
	NSString *spaced = [normalizedID stringByReplacingOccurrencesOfString:@"_" withString:@" "];
	return spaced.capitalizedString;
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
		return [[self scriptLabelForID:left] localizedCaseInsensitiveCompare:[self scriptLabelForID:right]];
	}];

	NSMutableArray<GlyphQuestScriptStat *> *stats = [NSMutableArray array];
	for (NSString *scriptID in scriptIDs) {
		NSDictionary<NSString *, NSNumber *> *bucket = scriptBuckets[scriptID];
		NSUInteger count = [bucket[@"count"] unsignedIntegerValue];
		CGFloat scriptScore = [bucket[@"score"] doubleValue];

		GlyphQuestScriptStat *stat = [[GlyphQuestScriptStat alloc] init];
		stat.scriptID = scriptID;
		stat.scoreSum = scriptScore;
		stat.total = count;
		stat.percent = count > 0 ? round((scriptScore / (CGFloat)count) * 1000.0) / 10.0 : 0.0;
		[stats addObject:stat];
	}
	result.scriptStats = stats;
	return result;
}

- (NSString *)formatScoreSum:(CGFloat)scoreSum {
	if (fabs(scoreSum - round(scoreSum)) < 0.001) {
		return [NSString stringWithFormat:@"%ld", (long)llround(scoreSum)];
	}
	NSString *text = [NSString stringWithFormat:@"%.2f", scoreSum];
	while ([text hasSuffix:@"0"]) {
		text = [text substringToIndex:text.length - 1];
	}
	if ([text hasSuffix:@"."]) {
		text = [text substringToIndex:text.length - 1];
	}
	return text;
}

- (void)updateScriptRowsWithStats:(NSArray<GlyphQuestScriptStat *> *)scriptStats {
	NSUInteger visibleCount = MIN(scriptStats.count, GQMaxScriptRows);
	self.scriptRowCount = visibleCount;

	for (NSUInteger index = 0; index < self.scriptRows.count; index++) {
		GlyphQuestScriptRowView *row = self.scriptRows[index];
		if (index >= visibleCount) {
			row.hidden = YES;
			continue;
		}

		GlyphQuestScriptStat *stat = scriptStats[index];
		row.hidden = YES;
		row.theme = self.currentTheme;
		NSString *name = [NSString stringWithFormat:@"%@  %@/%lu %@",
						  [self scriptLabelForID:stat.scriptID],
						  [self formatScoreSum:stat.scoreSum],
						  (unsigned long)stat.total,
						  GQGlyphUnit()];
		NSString *percent = [NSString stringWithFormat:@"%.1f%%", stat.percent];
		[row updateWithName:name percentText:percent progress:stat.percent];
	}

	[self updateModeVisibility];
	[self updatePaletteHeight];
}

- (void)updateDisplay {
	(void)self.view;
	GlyphQuestProgressResult *result = [self calculateProgressForFont:[self currentFont]];
	if (!result) {
		self.percentLabel.stringValue = @"-";
		self.countLabel.stringValue = @"";
		self.overallProgressBar.progress = 0.0;
		self.scriptRowCount = 0;
		self.scriptScrollView.hidden = YES;
		for (GlyphQuestScriptRowView *row in self.scriptRows) {
			row.hidden = YES;
		}
		[self updateModeVisibility];
		[self updatePaletteHeight];
		return;
	}

	self.percentLabel.stringValue = [NSString stringWithFormat:@"%.1f%%", result.percent];
	self.overallProgressBar.progress = result.percent;

	if (result.totalCount == 0) {
		self.countLabel.stringValue = GQLocalized(@"No exportable glyphs", @"対象グリフなし", @"没有可导出的字形", @"내보낼 글리프 없음");
	} else {
		self.countLabel.stringValue = [NSString stringWithFormat:@"%@ / %lu %@",
									   [self formatScoreSum:result.scoreSum],
									   (unsigned long)result.totalCount,
									   GQGlyphUnit()];
	}

	[self updateScriptRowsWithStats:result.scriptStats];
}

@end
