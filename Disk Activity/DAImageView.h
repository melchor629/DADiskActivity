//
//  DAImageView.h
//  Disk Activity
//
//  Created by Melchor Garau Madrigal on 04/05/14.
//  Copyright (c) 2014 Melchor Garau Madrigal. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DAImageView : NSImageView<NSMenuDelegate>

@property NSStatusItem* statusItem;
@property NSMenu* menu;

- (void)mouseEntered:(NSEvent *)theEvent;
- (void)mouseExited:(NSEvent *)theEvent;
- (void)mouseDown:(NSEvent *)theEvent;

@end
