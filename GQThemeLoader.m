#import "GQThemeSpec.h"

NSString * const GQSelectedThemeDefaultsKey = @"GlyphQuest.selectedThemeID";
const CGFloat GQProgressNearThreshold = 90.0;
const CGFloat GQProgressCompleteThreshold = 99.95;

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

static NSString *GQLocalizedName(NSString *english, NSString *japanese, NSString *chinese, NSString *korean) {
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

NSColor *GQColorFromHex(NSString *hex) {
	if (hex.length == 0) {
		return NSColor.clearColor;
	}
	NSString *clean = [hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([clean hasPrefix:@"#"]) {
		clean = [clean substringFromIndex:1];
	}
	if (clean.length != 6 && clean.length != 8) {
		return NSColor.clearColor;
	}
	unsigned int value = 0;
	[[NSScanner scannerWithString:clean] scanHexInt:&value];
	CGFloat alpha = 1.0;
	CGFloat red = 0.0;
	CGFloat green = 0.0;
	CGFloat blue = 0.0;
	if (clean.length == 8) {
		red = ((value >> 24) & 0xFF) / 255.0;
		green = ((value >> 16) & 0xFF) / 255.0;
		blue = ((value >> 8) & 0xFF) / 255.0;
		alpha = (value & 0xFF) / 255.0;
	} else {
		red = ((value >> 16) & 0xFF) / 255.0;
		green = ((value >> 8) & 0xFF) / 255.0;
		blue = (value & 0xFF) / 255.0;
	}
	return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}

NSArray<NSColor *> *GQColorsFromHexArray(id value) {
	if ([value isKindOfClass:[NSString class]]) {
		return @[GQColorFromHex((NSString *)value)];
	}
	if (![value isKindOfClass:[NSArray class]]) {
		return @[];
	}
	NSMutableArray<NSColor *> *colors = [NSMutableArray array];
	for (id item in (NSArray *)value) {
		if ([item isKindOfClass:[NSString class]]) {
			[colors addObject:GQColorFromHex((NSString *)item)];
		}
	}
	return colors;
}

static NSColor *GQColorFromObject(id value, NSColor *fallback) {
	if ([value isKindOfClass:[NSString class]]) {
		NSColor *color = GQColorFromHex((NSString *)value);
		return color ?: fallback;
	}
	return fallback;
}

@implementation GQProgressStyle

- (CGFloat)radiusForKey:(NSString *)key height:(CGFloat)height large:(BOOL)large {
	NSString *specificKey = large ? key : [key stringByAppendingString:@"_small"];
	id value = self.shape[specificKey];
	if (!value || [value isKindOfClass:[NSNull class]]) {
		value = self.shape[key];
	}
	if ([value isKindOfClass:[NSString class]] && [((NSString *)value) isEqualToString:@"auto"]) {
		return height / 2.0;
	}
	if ([value isKindOfClass:[NSNumber class]]) {
		return [(NSNumber *)value doubleValue];
	}
	return height / 2.0;
}

@end

@implementation GQThemeSpec

- (NSString *)displayName {
	return GQLocalizedName(self.englishName, self.japaneseName, self.chineseName, self.koreanName);
}

- (NSImage *)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle {
	NSURL *url = [bundle URLForResource:name withExtension:@"png" subdirectory:self.resourceSubdirectory];
	if (!url) {
		return nil;
	}
	return [[NSImage alloc] initWithContentsOfURL:url];
}

- (NSColor *)progressBezelTopColor { return self.progressStyle.bezelTopColor; }
- (NSColor *)progressBezelBottomColor { return self.progressStyle.bezelBottomColor; }
- (NSColor *)progressBezelStrokeColor { return self.progressStyle.bezelStrokeColor; }
- (NSColor *)progressTrackTopColor { return self.progressStyle.trackTopColor; }
- (NSColor *)progressTrackBottomColor { return self.progressStyle.trackBottomColor; }
- (NSColor *)progressTrackStrokeColor { return self.progressStyle.trackStrokeColor; }
- (NSColor *)progressRimColor { return self.progressStyle.rimColor; }
- (NSColor *)progressShadowColor { return self.progressStyle.shadowColor; }
- (NSArray<NSColor *> *)progressFillColors { return self.progressStyle.fillColors; }
- (NSArray<NSColor *> *)progressNearFillColors { return self.progressStyle.nearFillColors; }
- (NSArray<NSColor *> *)progressCompleteFillColors { return self.progressStyle.completeFillColors; }
- (NSColor *)progressFillStrokeColor { return self.progressStyle.fillStrokeColor; }
- (NSColor *)progressNearFillStrokeColor { return self.progressStyle.nearFillStrokeColor; }
- (NSColor *)progressCompleteFillStrokeColor { return self.progressStyle.completeFillStrokeColor; }

@end

GQProgressStyle *GQProgressStyleFromDictionary(NSDictionary *dictionary) {
	if (![dictionary isKindOfClass:[NSDictionary class]]) {
		return nil;
	}
	GQProgressStyle *style = [[GQProgressStyle alloc] init];
	style.rawProgress = dictionary;
	style.shape = [dictionary[@"shape"] isKindOfClass:[NSDictionary class]] ? dictionary[@"shape"] : @{};
	style.fillMode = [dictionary[@"fill_mode"] isKindOfClass:[NSString class]] ? dictionary[@"fill_mode"] : @"continuous";
	style.segments = [dictionary[@"segments"] isKindOfClass:[NSDictionary class]] ? dictionary[@"segments"] : nil;
	style.trackLayers = [dictionary[@"track_layers"] isKindOfClass:[NSArray class]] ? dictionary[@"track_layers"] : @[];
	style.fillLayers = [dictionary[@"fill_layers"] isKindOfClass:[NSArray class]] ? dictionary[@"fill_layers"] : @[];
	style.overlays = [dictionary[@"overlays"] isKindOfClass:[NSDictionary class]] ? dictionary[@"overlays"] : nil;
	style.gloss = [dictionary[@"gloss"] isKindOfClass:[NSDictionary class]] ? dictionary[@"gloss"] : nil;

	NSDictionary *bezel = [dictionary[@"bezel"] isKindOfClass:[NSDictionary class]] ? dictionary[@"bezel"] : @{};
	NSDictionary *track = [dictionary[@"track"] isKindOfClass:[NSDictionary class]] ? dictionary[@"track"] : @{};
	style.bezelTopColor = GQColorFromObject(bezel[@"top"], NSColor.grayColor);
	style.bezelBottomColor = GQColorFromObject(bezel[@"bottom"], NSColor.darkGrayColor);
	style.bezelStrokeColor = GQColorFromObject(bezel[@"stroke"], NSColor.blackColor);
	style.trackTopColor = GQColorFromObject(track[@"top"], NSColor.whiteColor);
	style.trackBottomColor = GQColorFromObject(track[@"bottom"], NSColor.lightGrayColor);
	style.trackStrokeColor = GQColorFromObject(track[@"stroke"], NSColor.clearColor);
	style.rimColor = GQColorFromObject(dictionary[@"rim"], NSColor.clearColor);
	style.shadowColor = GQColorFromObject(dictionary[@"shadow"], NSColor.clearColor);
	style.fillColors = GQColorsFromHexArray(dictionary[@"fill"]);
	style.nearFillColors = GQColorsFromHexArray(dictionary[@"near_fill"]);
	style.completeFillColors = GQColorsFromHexArray(dictionary[@"complete_fill"]);
	style.fillStrokeColor = GQColorFromObject(dictionary[@"fill_stroke"], NSColor.clearColor);
	style.nearFillStrokeColor = GQColorFromObject(dictionary[@"near_fill_stroke"], NSColor.clearColor);
	style.completeFillStrokeColor = GQColorFromObject(dictionary[@"complete_fill_stroke"], NSColor.clearColor);
	return style;
}

static GQThemeSpec *GQThemeFromDictionary(NSDictionary *dictionary, NSString *themeID) {
	GQThemeSpec *theme = [[GQThemeSpec alloc] init];
	theme.identifier = [dictionary[@"id"] isKindOfClass:[NSString class]] ? dictionary[@"id"] : themeID;
	theme.resourceSubdirectory = [NSString stringWithFormat:@"Themes/%@", theme.identifier];

	NSDictionary *names = [dictionary[@"names"] isKindOfClass:[NSDictionary class]] ? dictionary[@"names"] : @{};
	theme.englishName = names[@"en"] ?: theme.identifier;
	theme.japaneseName = names[@"ja"] ?: theme.englishName;
	theme.chineseName = names[@"zh"] ?: theme.englishName;
	theme.koreanName = names[@"ko"] ?: theme.englishName;
	theme.percentFontName = [dictionary[@"percent_font"] isKindOfClass:[NSString class]] ? dictionary[@"percent_font"] : @"Quicksand-Bold";

	NSDictionary *card = [dictionary[@"card"] isKindOfClass:[NSDictionary class]] ? dictionary[@"card"] : @{};
	theme.cardLeftCap = [card[@"left_cap"] respondsToSelector:@selector(doubleValue)] ? [card[@"left_cap"] doubleValue] : 135.0;
	theme.cardRightCap = [card[@"right_cap"] respondsToSelector:@selector(doubleValue)] ? [card[@"right_cap"] doubleValue] : 118.0;
	theme.titleLeading = [card[@"title_leading"] respondsToSelector:@selector(doubleValue)] ? [card[@"title_leading"] doubleValue] : 56.0;
	theme.cardSourceRect = NSZeroRect;
	theme.cardCenterTileX = 0.0;
	theme.cardCenterTileWidth = 0.0;
	theme.usesTiledCardCenter = [dictionary[@"uses_tiled_card_center"] boolValue];
	theme.toggleSourceRect = NSZeroRect;

	NSDictionary *colours = [dictionary[@"colours"] isKindOfClass:[NSDictionary class]] ? dictionary[@"colours"] : @{};
	theme.titleColor = GQColorFromObject(colours[@"title"], NSColor.labelColor);
	theme.progressTitleColor = GQColorFromObject(colours[@"progress_title"], theme.titleColor);
	theme.percentColor = GQColorFromObject(colours[@"percent"], theme.titleColor);
	theme.countColor = GQColorFromObject(colours[@"count"], theme.titleColor);
	theme.toggleTextColor = GQColorFromObject(colours[@"toggle_text"], NSColor.whiteColor);
	theme.toggleShadowColor = GQColorFromObject(colours[@"toggle_shadow"], NSColor.blackColor);
	theme.settingsTextColor = GQColorFromObject(colours[@"settings_text"], NSColor.whiteColor);
	theme.rowTextColor = GQColorFromObject(colours[@"row_text"], theme.titleColor);
	theme.rowPercentColor = GQColorFromObject(colours[@"row_percent"], theme.countColor);
	theme.rowTopColor = GQColorFromObject(colours[@"row_top"], NSColor.whiteColor);
	theme.rowBottomColor = GQColorFromObject(colours[@"row_bottom"], NSColor.lightGrayColor);
	theme.rowStrokeColor = GQColorFromObject(colours[@"row_stroke"], NSColor.grayColor);
	theme.rowAccentColor = GQColorFromObject(colours[@"row_accent"], NSColor.systemGreenColor);

	theme.progressStyle = GQProgressStyleFromDictionary([dictionary[@"progress"] isKindOfClass:[NSDictionary class]] ? dictionary[@"progress"] : @{});
	return theme;
}

static NSArray<NSString *> *GQDiscoveredThemeIDs(NSBundle *bundle) {
	NSString *themesPath = [[bundle resourcePath] stringByAppendingPathComponent:@"Themes"];
	NSArray<NSString *> *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:themesPath error:nil];
	if (entries.count == 0) {
		return @[@"forest", @"cyber", @"moonlight", @"candy", @"ocean", @"y2k"];
	}
	NSMutableArray<NSString *> *themeIDs = [NSMutableArray array];
	for (NSString *entry in [entries sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
		BOOL isDirectory = NO;
		NSString *fullPath = [themesPath stringByAppendingPathComponent:entry];
		if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory] && isDirectory) {
			NSString *jsonPath = [fullPath stringByAppendingPathComponent:@"theme.json"];
			if ([[NSFileManager defaultManager] fileExistsAtPath:jsonPath]) {
				[themeIDs addObject:entry];
			}
		}
	}
	return themeIDs;
}

NSArray<GQThemeSpec *> *GQThemeRegistry(void) {
	static NSArray<GQThemeSpec *> *themes;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSBundle *bundle = [NSBundle bundleForClass:[GQThemeSpec class]];
		NSMutableArray<GQThemeSpec *> *loadedThemes = [NSMutableArray array];
		for (NSString *themeID in GQDiscoveredThemeIDs(bundle)) {
			NSURL *jsonURL = [bundle URLForResource:@"theme" withExtension:@"json" subdirectory:[NSString stringWithFormat:@"Themes/%@", themeID]];
			if (!jsonURL) {
				continue;
			}
			NSData *data = [NSData dataWithContentsOfURL:jsonURL];
			if (data.length == 0) {
				continue;
			}
			id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
			if (![json isKindOfClass:[NSDictionary class]]) {
				continue;
			}
			GQThemeSpec *theme = GQThemeFromDictionary((NSDictionary *)json, themeID);
			if (theme) {
				[loadedThemes addObject:theme];
			}
		}
		themes = [loadedThemes copy];
	});
	return themes;
}

GQThemeSpec *GQThemeForIdentifier(NSString *identifier) {
	if (identifier.length > 0) {
		for (GQThemeSpec *theme in GQThemeRegistry()) {
			if ([theme.identifier isEqualToString:identifier]) {
				return theme;
			}
		}
	}
	for (GQThemeSpec *theme in GQThemeRegistry()) {
		if ([theme.identifier isEqualToString:@"forest"]) {
			return theme;
		}
	}
	return GQThemeRegistry().firstObject;
}

GQThemeSpec *GQSavedTheme(void) {
	NSString *savedID = [[NSUserDefaults standardUserDefaults] stringForKey:GQSelectedThemeDefaultsKey];
	return GQThemeForIdentifier(savedID);
}
