#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const GQSelectedThemeDefaultsKey;
extern const CGFloat GQProgressNearThreshold;
extern const CGFloat GQProgressCompleteThreshold;

@interface GQProgressStyle : NSObject
@property (nonatomic, copy) NSDictionary *rawProgress;
@property (nonatomic, copy) NSDictionary *shape;
@property (nonatomic, copy) NSString *fillMode;
@property (nonatomic, copy, nullable) NSDictionary *segments;
@property (nonatomic, copy) NSArray<NSDictionary *> *trackLayers;
@property (nonatomic, copy) NSArray<NSDictionary *> *fillLayers;
@property (nonatomic, copy, nullable) NSDictionary *overlays;
@property (nonatomic, copy, nullable) NSDictionary *gloss;
@property (nonatomic, strong) NSColor *bezelTopColor;
@property (nonatomic, strong) NSColor *bezelBottomColor;
@property (nonatomic, strong) NSColor *bezelStrokeColor;
@property (nonatomic, strong) NSColor *trackTopColor;
@property (nonatomic, strong) NSColor *trackBottomColor;
@property (nonatomic, strong) NSColor *trackStrokeColor;
@property (nonatomic, strong) NSColor *rimColor;
@property (nonatomic, strong) NSColor *shadowColor;
@property (nonatomic, copy) NSArray<NSColor *> *fillColors;
@property (nonatomic, copy) NSArray<NSColor *> *nearFillColors;
@property (nonatomic, copy) NSArray<NSColor *> *completeFillColors;
@property (nonatomic, strong) NSColor *fillStrokeColor;
@property (nonatomic, strong) NSColor *nearFillStrokeColor;
@property (nonatomic, strong) NSColor *completeFillStrokeColor;
- (CGFloat)radiusForKey:(NSString *)key height:(CGFloat)height large:(BOOL)large;
- (BOOL)usesChamferCorners;
- (BOOL)usesSlantedFillEnd;
- (CGFloat)chamferForKey:(NSString *)key height:(CGFloat)height large:(BOOL)large;
- (CGFloat)fillEndShearForHeight:(CGFloat)height large:(BOOL)large;
@end

@interface GQThemeSpec : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *englishName;
@property (nonatomic, copy) NSString *japaneseName;
@property (nonatomic, copy) NSString *chineseName;
@property (nonatomic, copy) NSString *koreanName;
@property (nonatomic, copy) NSString *resourceSubdirectory;
@property (nonatomic, copy) NSString *percentFontName;
@property (nonatomic) CGFloat cardLeftCap;
@property (nonatomic) CGFloat cardRightCap;
@property (nonatomic) NSRect cardSourceRect;
@property (nonatomic) CGFloat cardCenterTileX;
@property (nonatomic) CGFloat cardCenterTileWidth;
@property (nonatomic) BOOL usesTiledCardCenter;
@property (nonatomic) NSRect toggleSourceRect;
@property (nonatomic) CGFloat titleLeading;
@property (nonatomic) BOOL usesNativeAppearance;
@property (nonatomic, strong) NSColor *titleColor;
@property (nonatomic, strong) NSColor *progressTitleColor;
@property (nonatomic, strong) NSColor *percentColor;
@property (nonatomic, strong) NSColor *countColor;
@property (nonatomic, strong) NSColor *toggleTextColor;
@property (nonatomic, strong) NSColor *toggleShadowColor;
@property (nonatomic, strong) NSColor *settingsTextColor;
@property (nonatomic, strong) NSColor *rowTextColor;
@property (nonatomic, strong) NSColor *rowPercentColor;
@property (nonatomic, strong) NSColor *rowTopColor;
@property (nonatomic, strong) NSColor *rowBottomColor;
@property (nonatomic, strong) NSColor *rowStrokeColor;
@property (nonatomic, strong) NSColor *rowAccentColor;
@property (nonatomic, strong) GQProgressStyle *progressStyle;
@property (nonatomic, strong, readonly) NSColor *progressBezelTopColor;
@property (nonatomic, strong, readonly) NSColor *progressBezelBottomColor;
@property (nonatomic, strong, readonly) NSColor *progressBezelStrokeColor;
@property (nonatomic, strong, readonly) NSColor *progressTrackTopColor;
@property (nonatomic, strong, readonly) NSColor *progressTrackBottomColor;
@property (nonatomic, strong, readonly) NSColor *progressTrackStrokeColor;
@property (nonatomic, strong, readonly) NSColor *progressRimColor;
@property (nonatomic, strong, readonly) NSColor *progressShadowColor;
@property (nonatomic, copy, readonly) NSArray<NSColor *> *progressFillColors;
@property (nonatomic, copy, readonly) NSArray<NSColor *> *progressNearFillColors;
@property (nonatomic, copy, readonly) NSArray<NSColor *> *progressCompleteFillColors;
@property (nonatomic, strong, readonly) NSColor *progressFillStrokeColor;
@property (nonatomic, strong, readonly) NSColor *progressNearFillStrokeColor;
@property (nonatomic, strong, readonly) NSColor *progressCompleteFillStrokeColor;
- (NSString *)displayName;
- (nullable NSImage *)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;
@end

NSColor * _Nullable GQColorFromHex(NSString * _Nullable hex);
NSArray<NSColor *> *GQColorsFromHexArray(id _Nullable value);
GQProgressStyle *GQProgressStyleFromDictionary(NSDictionary * _Nullable dictionary);

NSArray<GQThemeSpec *> *GQThemeRegistry(void);
GQThemeSpec *GQThemeForIdentifier(NSString * _Nullable identifier);
GQThemeSpec *GQSavedTheme(void);
void GQRefreshNativeThemeAppearance(GQThemeSpec *theme);

@interface GQProgressRenderer : NSObject
+ (void)drawProgressInRect:(NSRect)bounds
                  progress:(CGFloat)progress
                     large:(BOOL)large
                     theme:(GQThemeSpec *)theme
                    bundle:(NSBundle *)bundle;
@end

NS_ASSUME_NONNULL_END
