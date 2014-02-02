//
//  DAMenuIcon.h
//  Disk Activity
//
//  Created by Melchor Garau Madrigal on 19/11/13.
//  Copyright (c) 2013 Melchor Garau Madrigal. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>
#import <IOKit/storage/IOBlockStorageDriver.h>
#import "GBLaunchAtLogin/GBLaunchAtLogin/GBLaunchAtLogin.h"

struct io {
    UInt64 input;
    int64_t ispeed;
    UInt64 output;
    int64_t ospeed;
};
typedef struct io io_s;

void getDISKcounters(io_iterator_t drivelist, struct io *io_s, NSObject *this);

/**
 *  Main Class, Application Delegate, where all the action happends, for now
 */
@interface DAMenuIcon : NSObject <NSApplicationDelegate> {
    NSStatusItem *statusItem;
    NSTimer *updateTimer;
    NSMenu *menu;
}

/**
 *  Main Window
 */
@property (assign) IBOutlet NSWindow *window;

/**
 *  Image variable for the status bar icon
 */
@property (strong) NSImage *graphImage;

/**
 *  Set if show or not icon in the Status bar
 */
@property BOOL icon;

/**
 *  Set if show or not text in the Status bar
 */
@property BOOL text;

/**
 *  A dictionary with the Product name of a disk
 */
@property (strong) NSMutableDictionary *disks;

/**
 *  Change the value of a (settings) item
 *
 *  @param object Value object to change to
 *  @param key    Key of the setting
 */
+ (void)setPreference:(id)object withKey:(NSString*)key;

/**
 *  Obtain the value of a (settings) item
 *
 *  @param key Key of the setting
 *
 *  @return Value object for the key
 */
+ (id)getPreference:(NSString*)key;

/**
 *  IBAction methods
 */
- (IBAction)updateDiskUsage:(id)sender;
- (IBAction)quit:(id)sender;
- (IBAction)preferences:(id)sender;
- (IBAction)showHideIcon:(id)sender;
- (IBAction)showHideText:(id)sender;
- (IBAction)startAtLogin:(id)sender;
- (IBAction)diskElementClick:(id)sender;

@end
