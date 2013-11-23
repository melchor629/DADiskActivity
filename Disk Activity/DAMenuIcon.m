//
//  DAMenuIcon.m
//  Disk Activity
//
//  Created by Melchor Garau Madrigal on 19/11/13.
//  Copyright (c) 2013 Melchor Garau Madrigal. All rights reserved.
//

#import "DAMenuIcon.h"

void getDISKcounters(io_iterator_t drivelist, io_s *io_s) {
    io_registry_entry_t drive       = 0;  /* needs release */
    UInt64          totalReadBytes  = 0;
    UInt64          totalWriteBytes = 0;

    while ((drive = IOIteratorNext(drivelist))) {
        CFNumberRef     number      = 0;  /* don't release */
        CFDictionaryRef properties  = 0;  /* needs release */
        CFDictionaryRef statistics  = 0;  /* don't release */
        UInt64          value       = 0;

        /* Obtain the properties for this drive object */

        IORegistryEntryCreateCFProperties(drive, (CFMutableDictionaryRef *) &properties, kCFAllocatorDefault, kNilOptions);

        /* Obtain the statistics from the drive properties */
        statistics = (CFDictionaryRef) CFDictionaryGetValue(properties, CFSTR(kIOBlockStorageDriverStatisticsKey));

        if (statistics) {
            /* Obtain the number of bytes read from the drive statistics */
            number = (CFNumberRef) CFDictionaryGetValue(statistics, CFSTR(kIOBlockStorageDriverStatisticsBytesReadKey));
            if (number) {
                CFNumberGetValue(number, kCFNumberSInt64Type, &value);
                totalReadBytes += value;
            }

            /* Obtain the number of bytes written from the drive statistics */
            number = (CFNumberRef) CFDictionaryGetValue (statistics, CFSTR(kIOBlockStorageDriverStatisticsBytesWrittenKey));
            if (number) {
                CFNumberGetValue(number, kCFNumberSInt64Type, &value);
                totalWriteBytes += value;
            }
        }
        /* Release resources */

        CFRelease(properties); properties = 0;
        IOObjectRelease(drive); drive = 0;

    }
    IOIteratorReset(drivelist);

    io_s->ispeed = totalReadBytes - io_s->input;
    io_s->ospeed = totalWriteBytes - io_s->output;
    io_s->input = totalReadBytes;
    io_s->output = totalWriteBytes;
}

@implementation DAMenuIcon
io_s io;
io_iterator_t drivelist  = IO_OBJECT_NULL;
mach_port_t masterPort = IO_OBJECT_NULL;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
}

- (void)awakeFromNib {
    int index = 0;
    _icon = false;
    _text = true;
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:loc(@"Quit") action:@selector(quit:) keyEquivalent:@""];
    NSMenuItem *preferences = [[NSMenuItem alloc] initWithTitle:loc(@"Preferences") action:@selector(preferences:) keyEquivalent:@""];
    NSMenuItem *icon = [[NSMenuItem alloc] initWithTitle:loc(@"ShowIcon") action:@selector(showHideIcon:) keyEquivalent:@""];
    NSMenuItem *text = [[NSMenuItem alloc] initWithTitle:loc(@"ShowText") action:@selector(showHideText:) keyEquivalent:@""];
    [quit setTarget:self];
    [preferences setTarget:self];
    [icon setTarget:self];
    [text setTarget:self]; [text setState:NSOnState];
    menu = [[NSMenu alloc] initWithTitle:@"Disk Activity"];
    [menu insertItem:icon atIndex:index++];
    [menu insertItem:text atIndex:index++];
    [menu insertItem:preferences atIndex:index++];
    [menu insertItem:quit atIndex:index++];

    statusItem = [[NSStatusBar systemStatusBar]
                   statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setHighlightMode:YES];
    [statusItem setEnabled:YES];
    [statusItem setToolTip:@"Disk Activity"];

    [statusItem setMenu:menu];
    [statusItem setTarget:self];

    // Title as Image
    _IconOff = [NSImage imageNamed:@"MenuBarIconOff"];
    _IconGreen = [NSImage imageNamed:@"MenuBarIconGreen"];
    _IconRed = [NSImage imageNamed:@"MenuBarIconRed"];
    _IconBoth = [NSImage imageNamed:@"MenuBarIconBoth"];
    [statusItem setImage:_IconOff];
    updateTimer = [NSTimer
                    scheduledTimerWithTimeInterval:(1.0)
                    target:self
                    selector:@selector(updateDiskUsage:)
                    userInfo:nil
                    repeats:YES];
    [updateTimer fire];

    /* get ports and services for drive stats */
    /* Obtain the I/O Kit communication handle */
    IOMasterPort(bootstrap_port, &masterPort);

    /* Obtain the list of all drive objects */
    IOServiceGetMatchingServices(masterPort,
                                 IOServiceMatching("IOBlockStorageDriver"),
                                 &drivelist);
    /* Update counters for first time */
    getDISKcounters(drivelist, &io);
}

- (IBAction)updateDiskUsage:(id)sender {
    getDISKcounters(drivelist, &io);
    NSMutableString *title = [[NSMutableString alloc] init];

    if(_text) {
        if(io.ispeed < 1000)
            [title appendFormat:@"%lliB/s", io.ispeed];
        else if(io.ispeed/1000 < 1000)
            [title appendFormat:@"%lliKB/s", io.ispeed/1000];
        else if(io.ispeed/1000/1000 < 1000)
            [title appendFormat:@"%lliMB/s", io.ispeed/1000/1000];
        [title appendString:@" - "];
        if(io.ospeed < 1000)
            [title appendFormat:@"%lliB/s", io.ospeed];
        else if(io.ospeed/1000 < 1000)
            [title appendFormat:@"%lliKB/s", io.ospeed/1000];
        else if(io.ospeed/1000/1000 < 1000)
            [title appendFormat:@"%lliMB/s", io.ospeed/1000/1000];
    }

    [statusItem setTitle:title];
    if(_icon) {
        if(io.ispeed > 1000 && io.ospeed < 1000)
            [statusItem setImage:_IconGreen];
        else if(io.ispeed < 1000 && io.ospeed > 1000)
            [statusItem setImage:_IconRed];
        else if(io.ispeed > 1000 && io.ospeed > 1000)
            [statusItem setImage:_IconBoth];
        else if(![[statusItem image] isEqualTo:_IconOff])
            [statusItem setImage:_IconOff];
    } else {
        if([statusItem image] != nil)
            [statusItem setImage:nil];
    }
}

- (IBAction)quit:(id)sender {
    exit(0);
}

- (IBAction)preferences:(id)sender {
    
}

- (IBAction)showHideIcon:(id)sender {
    _icon = !_icon;
    if(_icon)
        [[menu itemAtIndex:0] setState:NSOnState];
    else if(!_icon && _text)
        [[menu itemAtIndex:0] setState:NSOffState];
    else if(!_icon && !_text) {
        [[menu itemAtIndex:0] setState:NSOffState];
        [[menu itemAtIndex:1] setState:NSOnState];
        _text = true;
    }
}

- (IBAction)showHideText:(id)sender {
    _text = !_text;
    if(!_text && _icon)
        [menu setTitle:@""];
    else if(!_text && !_icon) {
        _icon = true;
        [[menu itemAtIndex:0] setState:NSOnState];
    }
    if(_text)
        [[menu itemAtIndex:1] setState:NSOnState];
    else
        [[menu itemAtIndex:1] setState:NSOffState];
}

@end