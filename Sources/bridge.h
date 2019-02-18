@import AppKit;

@interface NSMenu (MissingAPI)
// not public, but necessary if you want an NSMenu with the right system theme
- (BOOL)popUpMenuWithCorrectThemePositioningItem:(NSMenuItem *)arg1 atLocation:(struct CGPoint)arg2;
@end
