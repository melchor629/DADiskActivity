//
//  DAImageView.m
//  Disk Activity
//
//  Created by Melchor Garau Madrigal on 04/05/14.
//  Copyright (c) 2014 Melchor Garau Madrigal. All rights reserved.
//

#import "DAImageView.h"

@implementation DAImageView

NSTrackingArea* tArea;
bool isOpened = 0;

@synthesize statusItem;
@synthesize menu;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {}
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    if(isOpened) {
        [[NSColor selectedMenuItemColor] set];
        NSRectFill(dirtyRect);
    }
    [super drawRect:dirtyRect];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    [super mouseEntered:theEvent];
    NSLog(@"enter");
}

- (void)mouseExited:(NSEvent *)theEvent {
    [super mouseExited:theEvent];
    NSLog(@"exit");
}

- (void)mouseDown:(NSEvent *)theEvent {
    [super mouseDown:theEvent];
    isOpened = true;
    [self setNeedsDisplay];
    [self.statusItem popUpStatusItemMenu:self.menu];
}

- (NSMenu*)menu {
    return menu;
}

- (void)setMenu:(NSMenu *)_menu {
    menu = _menu;
    [menu setDelegate:self];
}

- (void)menuDidClose:(NSMenu*)menu {
    isOpened = false;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if(tArea)
        [self removeTrackingArea:tArea];

    NSTrackingAreaOptions opts = NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow;
    tArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:opts owner:self userInfo:nil];
    [self addTrackingArea:tArea];
}

@end
