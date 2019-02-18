#import <AppKit/AppKit.h>

@interface NSMenu (PrivateAPI)
- (BOOL)popUpMenuPositioningItem:(id)arg1 atLocation:(struct CGPoint)arg2 inView:(id)arg3 appearance:(id)arg4;
@end

@implementation NSMenu (MissingAPI)

// not public, but necessary if you want an NSMenu with the right system theme
- (BOOL)popUpMenuWithCorrectThemePositioningItem:(NSMenuItem *)arg1 atLocation:(struct CGPoint)arg2 {
    NSString *ifStyle = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    BOOL darkMode = (ifStyle && [ifStyle isEqualToString:@"Dark"]);

    NSAppearance *appearance = [NSAppearance appearanceNamed:darkMode ? NSAppearanceNameVibrantDark : NSAppearanceNameVibrantLight];

    return [self popUpMenuPositioningItem:arg1 atLocation:arg2 inView:nil appearance:appearance];
}

@end
