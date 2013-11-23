//
//  DAMenuIcon.h
//  Disk Activity
//
//  Created by Melchor Garau Madrigal on 19/11/13.
//  Copyright (c) 2013 Melchor Garau Madrigal. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/storage/IOBlockStorageDriver.h>

struct io {
    UInt64 input;
    int64_t ispeed;
    UInt64 output;
    int64_t ospeed;
};
typedef struct io io_s;

void getDISKcounters(io_iterator_t drivelist, struct io *io_s);

@interface DAMenuIcon : NSObject <NSApplicationDelegate> {
    NSStatusItem *statusItem;
    NSTimer *updateTimer;
    NSMenu *menu;
}

@property (assign) IBOutlet NSWindow *window;
@property NSImage *IconOff;
@property NSImage *IconRed;
@property NSImage *IconGreen;
@property NSImage *IconBoth;
@property BOOL icon;
@property BOOL text;

- (IBAction)updateDiskUsage:(id)sender;
- (IBAction)quit:(id)sender;
- (IBAction)preferences:(id)sender;
- (IBAction)showHideIcon:(id)sender;
- (IBAction)showHideText:(id)sender;

@end
