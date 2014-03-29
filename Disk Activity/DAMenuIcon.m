//
//  DAMenuIcon.m
//  Disk Activity
//
//  Created by Melchor Garau Madrigal on 19/11/13.
//  Copyright (c) 2013 Melchor Garau Madrigal. All rights reserved.
//

#import "DAMenuIcon.h"

void getDISKcounters(io_iterator_t drivelist, io_s *io_s, NSObject *this) {
    io_registry_entry_t drive       = 0;  /* needs release */
    UInt64          totalReadBytes  = 0;
    UInt64          totalWriteBytes = 0;
    DAMenuIcon *self = (DAMenuIcon*) this;
    NSDictionary *disks = [self disks];

    while ((drive = IOIteratorNext(drivelist))) {
        CFNumberRef     number      = 0;  /* don't release */
        CFDictionaryRef properties  = 0;  /* needs release */
        CFDictionaryRef statistics  = 0;  /* don't release */
        UInt64          value       = 0;

        /* Obtain the name of the Device (not partition) */
        const char* str;
        CFStringRef cfstr;
        io_registry_entry_t hdd = 0;
        CFDictionaryRef properties2 = 0;
        CFDictionaryRef statistics2 = 0;

        IORegistryEntryGetParentEntry(drive, kIOServicePlane, &hdd);
        IORegistryEntryCreateCFProperties(hdd, (CFMutableDictionaryRef*) &properties2, kCFAllocatorDefault, kNilOptions);
        statistics2 = (CFDictionaryRef) CFDictionaryGetValue(properties2, CFSTR("Device Characteristics"));
        cfstr = (CFStringRef) CFDictionaryGetValue(statistics2, CFSTR("Product Name"));
        str = CFStringGetCStringPtr(cfstr, CFStringGetSystemEncoding());

        IOObjectRelease(hdd); hdd = 0;
        CFRelease(properties2); properties2 = 0;
        NSString *nsstr = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];

        //Determine if has to appear in the disk activity or not
        if(![((NSNumber*) [disks valueForKey:nsstr]) boolValue])
            continue;

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
            number = (CFNumberRef) CFDictionaryGetValue(statistics, CFSTR(kIOBlockStorageDriverStatisticsBytesWrittenKey));
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
io_iterator_t drivelist = IO_OBJECT_NULL;
mach_port_t masterPort  = IO_OBJECT_NULL;
IONotificationPortRef ionotif, terminationNotificationPort;
DAMenuIcon *this;

@synthesize graphImage = anImage;
@synthesize disks = disks;

void devicePlugged() {
    IOServiceGetMatchingServices(masterPort,
                                 IOServiceMatching("IOBlockStorageDriver"),
                                 &drivelist);

    io_registry_entry_t drive       = 0;  /* needs release */
    DAMenuIcon *self = (DAMenuIcon*) this;
    NSMutableDictionary *disks = [self disks];
    NSMutableArray *validDisks = [[NSMutableArray alloc] init];

    while ((drive = IOIteratorNext(drivelist))) {
        /* Obtain the name of the Device (not partition) */
        const char* str;
        CFStringRef cfstr;
        io_registry_entry_t hdd = 0;
        CFDictionaryRef properties2 = 0;
        CFDictionaryRef statistics2 = 0;

        IORegistryEntryGetParentEntry(drive, kIOServicePlane, &hdd);
        IORegistryEntryCreateCFProperties(hdd, (CFMutableDictionaryRef*) &properties2, kCFAllocatorDefault, kNilOptions);
        statistics2 = (CFDictionaryRef) CFDictionaryGetValue(properties2, CFSTR("Device Characteristics"));
        cfstr = (CFStringRef) CFDictionaryGetValue(statistics2, CFSTR("Product Name"));
        str = CFStringGetCStringPtr(cfstr, CFStringGetSystemEncoding());

        NSString *nsstr = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
        [validDisks addObject:nsstr];

        /* Release resources */
        IOObjectRelease(drive); drive = 0;
        IOObjectRelease(hdd); hdd = 0;
        CFRelease(properties2); properties2 = 0;

    }
    IOIteratorReset(drivelist);

    NSEnumerator *nsenum = [validDisks objectEnumerator];
    NSString * key;
    while((key = [nsenum nextObject])) {
        if([disks objectForKey:key] == nil)
            [disks setValue:[NSNumber numberWithInt:1] forKey:key];
    }

    getDISKcounters(drivelist, &io, this);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
}

- (void)awakeFromNib {
    this = self;
    disks = [[NSMutableDictionary alloc] init];
    //Preferences
    [self preferences];
    _icon = [[DAMenuIcon getPreference:@"ShowIcon"] boolValue];
    _text = [[DAMenuIcon getPreference:@"ShowText"] boolValue];

    //Add menu items
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:loc(@"Quit") action:@selector(quit:) keyEquivalent:@""];
    NSMenuItem *preferences = [[NSMenuItem alloc] initWithTitle:loc(@"Preferences") action:@selector(preferences:) keyEquivalent:@""];
    NSMenuItem *icon = [[NSMenuItem alloc] initWithTitle:loc(@"ShowIcon") action:@selector(showHideIcon:) keyEquivalent:@""];
    NSMenuItem *text = [[NSMenuItem alloc] initWithTitle:loc(@"ShowText") action:@selector(showHideText:) keyEquivalent:@""];
    NSMenuItem *sal = [[NSMenuItem alloc] initWithTitle:loc(@"StartAtLogin") action:@selector(startAtLogin:) keyEquivalent:@""];
    NSMenuItem *disk = [[NSMenuItem alloc] initWithTitle:@"Disks" action:NULL keyEquivalent:@""];

    [quit setTarget:self];
    [disk setTarget:self];
    [preferences setTarget:self];
    [icon setTarget:self]; [icon setState:_icon ? NSOnState : NSOffState];
    [text setTarget:self]; [text setState:_text ? NSOnState : NSOffState];
    [sal setTarget:self]; [sal setState:([GBLaunchAtLogin isLoginItem] ? NSOnState : NSOffState)];

    NSMenu *diskM = [[NSMenu alloc] initWithTitle:@"Disks"];

    //Alloc and init Menu and fill with menu items
    menu = [[NSMenu alloc] initWithTitle:@"Disk Activity"];
    [menu addItem:icon];
    [menu addItem:text];
    [menu addItem:disk]; [menu setSubmenu:diskM forItem:disk];
    [menu addItem:preferences];
    [menu addItem:sal];
    [menu addItem:quit];

    //Add the item to Status Bar
    statusItem = [[NSStatusBar systemStatusBar]
                   statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setHighlightMode:YES];
    [statusItem setEnabled:YES];
    [statusItem setMenu:menu];
    [statusItem setTarget:self];

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
    devicePlugged();
    getDISKcounters(drivelist, &io, self);

    /* Add a listener to watch Un/Plug of devices */
    /* http://stackoverflow.com/questions/9918429/how-to-know-when-a-hid-usb-bluetooth-device-is-connected-in-cocoa/9918575#9918575 */
    mach_port_t port = 0;
    ionotif = IONotificationPortCreate(port);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(ionotif), kCFRunLoopDefaultMode);
    CFMutableDictionaryRef matchingDict = IOServiceMatching("IOBlockStorageDriver");
    CFRetain(matchingDict); // Need to use it twice and IOServiceAddMatchingNotification() consumes a reference

    CFDictionaryAddValue(matchingDict, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDRS232Type));

    io_iterator_t portIterator = 0;
    // Register for notifications when a serial port is added to the system
    kern_return_t result = IOServiceAddMatchingNotification(ionotif,
                                                            kIOPublishNotification,
                                                            matchingDict,
                                                            devicePlugged,
                                                            (__bridge void *)(self),
                                                            &portIterator);
    while (IOIteratorNext(portIterator)) {}; // Run out the iterator or notifications won't start (you can also use it to iterate the available devices).

    // Also register for removal notifications
    terminationNotificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    CFRunLoopAddSource(CFRunLoopGetCurrent(),
                       IONotificationPortGetRunLoopSource(terminationNotificationPort),
                       kCFRunLoopDefaultMode);
    result = IOServiceAddMatchingNotification(terminationNotificationPort,
                                              kIOTerminatedNotification,
                                              matchingDict,
                                              devicePlugged,
                                              (__bridge void *)(self),         // refCon/contextInfo
                                              &portIterator);

    while (IOIteratorNext(portIterator)) {}; // Run out the iterator or notifications won't start (you can also use it to iterate the available devices).
}

- (IBAction)updateDiskUsage:(id)sender {
    getDISKcounters(drivelist, &io, self);
    float imgWidth = 60.0;
         if(_text && !_icon) imgWidth = 44;
    else if(!_text && _icon) imgWidth = 16;
    NSString *readS = [NSString alloc], *writeS = [NSString alloc];
    anImage = [[NSImage alloc] initWithSize:NSMakeSize(imgWidth, 21.0)];
    NSColor *green = [NSColor colorWithRed:10.0/255.0 green:160/255.0 blue:15/255.0 alpha:1];
    NSColor *red =   [NSColor colorWithRed:255/255.0  green:10/230.0  blue:15/255.0 alpha:1];

    if(_text) {
        if(io.ispeed < 1000)
            readS = [readS initWithFormat:@"%lliB/s", io.ispeed];
        else if(io.ispeed/1000 < 1000)
            readS = [readS initWithFormat:@"%lliKB/s", io.ispeed/1000];
        else if(io.ispeed/1000/1000 < 1000)
            readS = [readS initWithFormat:@"%.1fMB/s", io.ispeed/1000.0/1000.0];
        else if(io.ispeed/1000/1000 > 1000)
            readS = [readS initWithFormat:@"%.1GB/s", io.ispeed/1000.0/1000.0/1000.0];

        if(io.ospeed < 1000)
            writeS = [writeS initWithFormat:@"%lliB/s", io.ospeed];
        else if(io.ospeed/1000 < 1000)
            writeS = [writeS initWithFormat:@"%lliKB/s", io.ospeed/1000];
        else if(io.ospeed/1000/1000 < 1000)
            writeS = [writeS initWithFormat:@"%.1fMB/s", io.ospeed/1000.0/1000.0];
        else if(io.ospeed/1000/1000 > 1000)
            writeS = [writeS initWithFormat:@"%.1GB/s", io.ospeed/1000.0/1000.0/1000.0];

        [anImage lockFocus];
        NSFont *f = [NSFont fontWithName:@"Lucida Grande" size:9.0];
        //Read speed
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        [style setAlignment:_icon ? NSLeftTextAlignment : NSRightTextAlignment];
        NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:f,
                                    NSFontAttributeName, green,
                                    NSForegroundColorAttributeName, style,
                                    NSParagraphStyleAttributeName, nil];
        [readS drawInRect:NSMakeRect(_icon ? 16 : 0, 12, [anImage size].width, 10) withAttributes:attributes];
        //Write speed
        attributes = [NSDictionary dictionaryWithObjectsAndKeys:f,
                      NSFontAttributeName, red,
                      NSForegroundColorAttributeName, style,
                      NSParagraphStyleAttributeName, nil];
        [writeS drawInRect:NSMakeRect(_icon ? 16 : 0, 2, [anImage size].width, 10) withAttributes:attributes];
        [anImage unlockFocus];
    }

    if(_icon) {
        float read = io.ispeed / 1000.0 * 18 / 2000.0;
        float write = io.ospeed / 1000.0 * 18 / 2000.0;
        read = read > 18.0 ? 18.0 : read;
        write = write > 18.0 ? 18.0 : write;

        [anImage lockFocus];
        //Background bars
        [[NSColor colorWithRed:100/255.0 green:100/255.0 blue:100/255.0 alpha:0.3] setFill];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(2, 1, 5, 18)] fill];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(9, 1, 5, 18)] fill];
        //Read bar
        [green setFill];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(2, 1, 5, read)] fill];
        //Write bar
        [red setFill];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(9, 1, 5, write)] fill];
        [anImage unlockFocus];
    }

    //Set final image
    [statusItem setImage:anImage];[anImage setBackgroundColor:[NSColor colorWithRed:1 green:1 blue:1 alpha:1]];
    [statusItem setAlternateImage:anImage];
    [self setDisksToMenu];
}

- (IBAction)quit:(id)sender {
    IONotificationPortDestroy(ionotif);
    IONotificationPortDestroy(terminationNotificationPort);
    exit(0);
}

- (IBAction)preferences:(id)sender {

}

- (IBAction)showHideIcon:(id)sender {
    _icon = !_icon;
    [DAMenuIcon setPreference:[NSNumber numberWithBool:_icon] withKey:@"ShowIcon"];
    [DAMenuIcon setPreference:[NSNumber numberWithBool:_text] withKey:@"ShowText"];
    NSMenuItem *icon = [menu itemWithTitle:loc(@"ShowIcon")];
    if(_icon)
        [icon setState:NSOnState];
    else if(!_icon && _text)
        [icon setState:NSOffState];
    else if(!_icon && !_text) {
        [icon setState:NSOffState];
        [[menu itemWithTitle:loc(@"ShowText")] setState:NSOnState];
        _text = true;
    }
}

- (IBAction)showHideText:(id)sender {
    _text = !_text;
    NSMenuItem *text = [menu itemWithTitle:loc(@"ShowText")];
    if(!_text && !_icon) {
        _icon = true;
        [[menu itemWithTitle:loc(@"ShowIcon")] setState:NSOnState];
    }
    if(_text)
        [text setState:NSOnState];
    else
        [text setState:NSOffState];
}

- (IBAction)startAtLogin:(id)sender {
    NSMenuItem *sal = [menu itemWithTitle:loc(@"StartAtLogin")];
    if(![GBLaunchAtLogin isLoginItem] && [sal state] == NSOffState) {
        [GBLaunchAtLogin addAppAsLoginItem];
        [sal setState:NSOnState];
        [DAMenuIcon setPreference:[NSNumber numberWithBool:YES] withKey:@"OpenAtStart"];
    } else if([GBLaunchAtLogin isLoginItem] && [sal state] == NSOnState) {
        [GBLaunchAtLogin removeAppFromLoginItems];
        [sal setState:NSOffState];
        [DAMenuIcon setPreference:[NSNumber numberWithBool:NO] withKey:@"OpenAtStart"];
    }
}

- (IBAction)diskElementClick:(id)sender {
    NSMenuItem *disk = (NSMenuItem*) sender;
    NSString *key = [disk title];
    if([disk state] == NSOnState) {
        [disks setValue:[NSNumber numberWithInt:0] forKey:key];
        [disk setState:NSOffState];
    } else if([disk state] == NSOffState) {
        [disks setValue:[NSNumber numberWithInt:1] forKey:key];
        [disk setState:NSOnState];
    }
    getDISKcounters(drivelist, &io, self); //TODO Temp FIX
}

- (void)preferences {
    NSMutableDictionary *appDefaults = [NSMutableDictionary
                                 dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"ShowIcon"];
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"ShowText"];
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"OpenAtStart"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}

+ (void)setPreference:(id)object withKey:(NSString*)key {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:object forKey:key];
}

+ (id)getPreference:(NSString*)key {
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

- (void)setDisksToMenu {
    NSEnumerator *nsenum = [disks keyEnumerator];
    NSString *key;
    NSMenu *diskMenu = [[NSMenu alloc] init];
    while((key = [nsenum nextObject])) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:key action:@selector(diskElementClick:) keyEquivalent:@""];
        [item setTarget:self];
        [item setState:[(((NSNumber*) [disks valueForKey:key])) integerValue]];
        [diskMenu addItem:item];
    }
    [menu setSubmenu:diskMenu forItem:[menu itemWithTitle:@"Disks"]];
}

@end