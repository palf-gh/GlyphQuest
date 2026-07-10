//
//  GQPalettePanel.h
//  GlyphQuest
//
//  Shared palette visual UI (GlyphsCore-free) for GlyphQuestPalette and theme samples.
//

#import <Cocoa/Cocoa.h>

#import "GQThemeSpec.h"

NS_ASSUME_NONNULL_BEGIN

extern const CGFloat GQPaletteWidth;
extern const CGFloat GQPaletteHeight;

NSString *GQLanguageKey(void);
void GQForceLanguageKey(NSString * _Nullable localeKey);
NSString *GQLocalized(NSString *english, NSString *japanese, NSString *chinese, NSString *korean);
NSString *GQScriptLabelForID(NSString *scriptID);
void GQRegisterBundledFonts(NSBundle *bundle);

@interface GQScriptStat : NSObject
@property (nonatomic, copy) NSString *scriptID;
@property (nonatomic) CGFloat percent;
@property (nonatomic) CGFloat scoreSum;
@property (nonatomic) NSUInteger total;
@end

@interface GQThemePopoverView : NSView
@end

@interface GQThemeChoiceButton : NSButton
@property (nonatomic, strong) GQThemeSpec *themeSpec;
@property (nonatomic) BOOL selectedTheme;
@end

@interface GQPalettePanelView : NSView

@property (nonatomic, strong) GQThemeSpec *theme;
@property (nonatomic, strong, nullable) NSBundle *resourceBundle; // nil => bundleForClass
@property (nonatomic) BOOL captureCompositing; // YES => SourceOver (sample capture); NO => Copy (Glyphs vibrancy)
@property (nonatomic, weak, nullable) id target; // toggle / settings actions
@property (nonatomic, readonly) NSButton *scriptToggleButton;
@property (nonatomic, readonly) NSButton *settingsButton;

- (void)buildInterfaceIfNeeded;
- (void)applyTheme:(GQThemeSpec *)theme;
- (void)layoutPanel;
- (void)setOverviewProgress:(CGFloat)percent scoreSum:(CGFloat)scoreSum totalCount:(NSUInteger)totalCount;
- (void)setOverviewUnavailable;
- (void)updateScriptRowsWithStats:(NSArray<GQScriptStat *> *)scriptStats;
- (void)updateModeVisibility;

@end

NS_ASSUME_NONNULL_END
