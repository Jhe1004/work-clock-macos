#import <Cocoa/Cocoa.h>

static void DrawIcon(CGFloat size, NSString *path) {
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(size, size)];
    [image lockFocus];
    CGFloat scale = size / 1024.0;
    NSRect canvas = NSMakeRect(0, 0, size, size);
    NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(canvas, 30 * scale, 30 * scale) xRadius:220 * scale yRadius:220 * scale];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithRed:0.05 green:0.10 blue:0.08 alpha:1]
                                                        endingColor:[NSColor colorWithRed:0.08 green:0.19 blue:0.13 alpha:1]];
    [gradient drawInBezierPath:background angle:-45];
    [[NSColor colorWithRed:0.35 green:0.92 blue:0.57 alpha:1] setStroke];
    NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(220 * scale, 220 * scale, 584 * scale, 584 * scale)];
    ring.lineWidth = 68 * scale; [ring stroke];
    NSBezierPath *hand = [NSBezierPath new];
    [hand moveToPoint:NSMakePoint(512 * scale, 512 * scale)]; [hand lineToPoint:NSMakePoint(512 * scale, 675 * scale)];
    [hand moveToPoint:NSMakePoint(512 * scale, 512 * scale)]; [hand lineToPoint:NSMakePoint(650 * scale, 430 * scale)];
    hand.lineWidth = 55 * scale; hand.lineCapStyle = NSLineCapStyleRound; hand.lineJoinStyle = NSLineJoinStyleRound; [hand stroke];
    [[NSColor colorWithWhite:1 alpha:0.9] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(474 * scale, 474 * scale, 76 * scale, 76 * scale)] fill];
    [image unlockFocus];
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithData:image.TIFFRepresentation];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [png writeToFile:path atomically:YES];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        NSString *folder = [NSString stringWithUTF8String:argv[1]];
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        NSArray *entries = @[
            @[@"icon_16x16.png", @16], @[@"icon_16x16@2x.png", @32],
            @[@"icon_32x32.png", @32], @[@"icon_32x32@2x.png", @64],
            @[@"icon_128x128.png", @128], @[@"icon_128x128@2x.png", @256],
            @[@"icon_256x256.png", @256], @[@"icon_256x256@2x.png", @512],
            @[@"icon_512x512.png", @512], @[@"icon_512x512@2x.png", @1024]
        ];
        for (NSArray *entry in entries) DrawIcon([entry[1] doubleValue], [folder stringByAppendingPathComponent:entry[0]]);
    }
    return 0;
}
