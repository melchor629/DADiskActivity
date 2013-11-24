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
int quitI, preferencesI, iconI, textI, graphI;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
}

- (void)awakeFromNib {
    int index = 0;
    _icon = false;
    _text = true;

    //Add menu items
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:loc(@"Quit") action:@selector(quit:) keyEquivalent:@""];
    NSMenuItem *preferences = [[NSMenuItem alloc] initWithTitle:loc(@"Preferences") action:@selector(preferences:) keyEquivalent:@""];
    NSMenuItem *icon = [[NSMenuItem alloc] initWithTitle:loc(@"ShowIcon") action:@selector(showHideIcon:) keyEquivalent:@""];
    NSMenuItem *text = [[NSMenuItem alloc] initWithTitle:loc(@"ShowText") action:@selector(showHideText:) keyEquivalent:@""];
    [quit setTarget:self];
    [preferences setTarget:self];
    [icon setTarget:self];
    [text setTarget:self]; [text setState:NSOnState];
    //Alloc and init Menu and fill with menu items
    menu = [[NSMenu alloc] initWithTitle:@"Disk Activity"];
    [menu insertItem:icon atIndex:index]; iconI = index++;
    [menu insertItem:text atIndex:index]; textI = index++;
    [menu insertItem:preferences atIndex:index]; preferencesI = index++;
    [menu insertItem:quit atIndex:index]; quitI = index++;

    //Add the item to Status Bar
    statusItem = [[NSStatusBar systemStatusBar]
                   statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setHighlightMode:YES];
    [statusItem setEnabled:YES];
    [statusItem setToolTip:@"Disk Activity"];
    [statusItem setMenu:menu];
    [statusItem setTarget:self];

    //Text and Image
    /*_IconOff = [NSImage imageNamed:@"MenuBarIconOff"];
    _IconGreen = [NSImage imageNamed:@"MenuBarIconGreen"];
    _IconRed = [NSImage imageNamed:@"MenuBarIconRed"];
    _IconBoth = [NSImage imageNamed:@"MenuBarIconBoth"];
    [statusItem setImage:_IconOff];*/

    //Timer to update information
    updateTimer = [NSTimer
                    scheduledTimerWithTimeInterval:(1.0)
                    target:self
                    selector:@selector(updateDiskUsage:)
                    userInfo:nil
                    repeats:YES];
    [updateTimer fire];

    /* Get ports and services for drive stats */
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
    //NSMutableString *title = [[NSMutableString alloc] init];
    NSString *readS = [NSString alloc], *writeS = [NSString alloc];
    NSImage *anImage = [[NSImage alloc] initWithSize:NSMakeSize(60.0, 21.0)];

    if(_text) {
        /*if(io.ispeed < 1000)
            [title appendFormat:@"%lliB/s", io.ispeed];
        else if(io.ispeed/1000 < 1000)
            [title appendFormat:@"%lliKB/s", io.ispeed/1000];
        else if(io.ispeed/1000/1000 < 1000)
            [title appendFormat:@"%.1fMB/s", io.ispeed/1000.0/1000.0];
        [title appendString:@" - "];
        if(io.ospeed < 1000)
            [title appendFormat:@"%lliB/s", io.ospeed];
        else if(io.ospeed/1000 < 1000)
            [title appendFormat:@"%lliKB/s", io.ospeed/1000];
        else if(io.ospeed/1000/1000 < 1000)
            [title appendFormat:@"%.1fMB/s", io.ospeed/1000.0/1000.0];*/
        if(io.ispeed < 1000)
            readS = [readS initWithFormat:@"%lliB/s", io.ispeed];
        else if(io.ispeed/1000 < 1000)
            readS = [readS initWithFormat:@"%lliKB/s", io.ispeed/1000];
        else if(io.ispeed/1000/1000 < 1000)
            readS = [readS initWithFormat:@"%.1fMB/s", io.ispeed/1000.0/1000.0];

        if(io.ospeed < 1000)
            writeS = [writeS initWithFormat:@"%lliB/s", io.ospeed];
        else if(io.ospeed/1000 < 1000)
            writeS = [writeS initWithFormat:@"%lliKB/s", io.ospeed/1000];
        else if(io.ospeed/1000/1000 < 1000)
            writeS = [writeS initWithFormat:@"%.1fMB/s", io.ospeed/1000.0/1000.0];
        [anImage lockFocus];
        NSFont *f = [NSFont fontWithName:@"Lucida Grande" size:9.0];
        NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:f,
                                    NSFontAttributeName, [NSColor colorWithRed:10.0/255.0 green:180/255.0 blue:15/255.0 alpha:1],
                                    NSForegroundColorAttributeName, nil];
        [readS drawAtPoint:NSMakePoint(16, 10) withAttributes:attributes];
        attributes = [NSDictionary dictionaryWithObjectsAndKeys:f,
                      NSFontAttributeName, [NSColor colorWithRed:255/255.0 green:10/230.0 blue:15/255.0 alpha:1],
                      NSForegroundColorAttributeName, nil];
        [writeS drawAtPoint:NSMakePoint(16, 0) withAttributes:attributes];
        [anImage unlockFocus];
        [statusItem setImage:anImage];
    }

    //[statusItem setTitle:title];
    if(_icon) {
        /*if(io.ispeed > 1000 && io.ospeed < 1000)
            [statusItem setImage:_IconGreen];
        else if(io.ispeed < 1000 && io.ospeed > 1000)
            [statusItem setImage:_IconRed];
        else if(io.ispeed > 1000 && io.ospeed > 1000)
            [statusItem setImage:_IconBoth];
        else if(![[statusItem image] isEqualTo:_IconOff])
            [statusItem setImage:_IconOff];*/
        float read = io.ispeed / 1000.0 * 18 / 2000.0;
        float write = io.ospeed / 1000.0 * 18 / 2000.0;
        read = read > 18.0 ? 18.0 : read;
        write = write > 18.0 ? 18.0 : write;

        [anImage lockFocus];
        [[NSColor colorWithRed:100/255.0 green:100/255.0 blue:100/255.0 alpha:0.3] setFill];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(2, 1, 5, 18)] fill];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(9, 1, 5, 18)] fill];
        [[NSColor colorWithRed:50.0/255.0 green:255/255.0 blue:55/255.0 alpha:1] setFill];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(2, 1, 5, read)] fill];
        [[NSColor colorWithRed:255/255.0 green:50/255.0 blue:55/255.0 alpha:1] setFill];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(9, 1, 5, write)] fill];
        [anImage unlockFocus];
        [statusItem setImage:anImage];
    }/* else {
        if([statusItem image] != nil)
            [statusItem setImage:nil];
    }*/
}

- (IBAction)quit:(id)sender {
    exit(0);
}

- (IBAction)preferences:(id)sender {

}

- (IBAction)showHideIcon:(id)sender {
    _icon = !_icon;
    if(_icon)
        [[menu itemAtIndex:iconI] setState:NSOnState];
    else if(!_icon && _text)
        [[menu itemAtIndex:iconI] setState:NSOffState];
    else if(!_icon && !_text) {
        [[menu itemAtIndex:iconI] setState:NSOffState];
        [[menu itemAtIndex:textI] setState:NSOnState];
        _text = true;
    }
}

- (IBAction)showHideText:(id)sender {
    _text = !_text;
    if(!_text && _icon)
        [menu setTitle:@""];
    else if(!_text && !_icon) {
        _icon = true;
        [[menu itemAtIndex:iconI] setState:NSOnState];
    }
    if(_text)
        [[menu itemAtIndex:textI] setState:NSOnState];
    else
        [[menu itemAtIndex:textI] setState:NSOffState];
}

@end