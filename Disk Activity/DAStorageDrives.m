//
//  DAStorageDrives.m
//  Disk Activity
//
//  Created by Melchor Garau Madrigal on 9/4/16.
//  Copyright © 2016 Melchor Garau Madrigal. All rights reserved.
//

#import "DAStorageDrives.h"

#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>
#include <IOKit/storage/IOBlockStorageDriver.h>

@interface Drive : NSObject
@property NSMutableArray* history;
@property io_speed_t* speed;
@property UInt64 bytesRead;
@property UInt64 bytesWrote;

+ (Drive*) new;

@end

@implementation Drive
- (id) init {
    self = [super init];
    if(self) {
        [self setHistory: [[NSMutableArray alloc] init]];
        [self setSpeed: malloc(sizeof(io_speed_t))];
    }
    return self;
}

+ (Drive*) new {
    return [[Drive alloc] init];
}
@end


static void devicePlugged(void* this, io_iterator_t iterator);
static void getDISKcounters(io_iterator_t drivelist, NSObject *this);

@implementation DAStorageDrives {
    io_iterator_t drivelist;
    mach_port_t masterPort;
    IONotificationPortRef ionotif, terminationNotificationPort;
    io_speed_t currentSpeed;

    NSMutableDictionary* disks;
    NSTimer* updateTimer;
}


- (id) init {
    self = [super init];

    if(self) {
        self->drivelist = IO_OBJECT_NULL;
        self->masterPort = IO_OBJECT_NULL;
        self->disks = [[NSMutableDictionary alloc] init];

        /* Get ports and services for drive stats */
        /* Obtain the I/O Kit communication handle */
        IOMasterPort(bootstrap_port, &masterPort);

        /* Obtain the list of all drive objects */
        IOServiceGetMatchingServices(masterPort,
                                     IOServiceMatching("IOBlockStorageDriver"),
                                     &drivelist);

        /* Update counters for first time */
        devicePlugged((__bridge void*) self, drivelist);

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

        updateTimer = [NSTimer
                       scheduledTimerWithTimeInterval:(1.0)
                       target:self
                       selector:@selector(timerFired:)
                       userInfo:nil
                       repeats:YES];
        [updateTimer fire];
    }

    return self;
}

- (const io_speed_t*) speedForDevice:(NSString *)device {
    return [(Drive*) [disks objectForKey:device] speed];
}

- (NSArray*) drives {
    return [disks allKeys];
}

- (void) finalize {
    [super finalize];
    IONotificationPortDestroy(ionotif);
    IONotificationPortDestroy(terminationNotificationPort);
}

- (void) timerFired:(id) selector {
    getDISKcounters(drivelist, self);
    if([self delegate]) {
        [[self delegate] speedCalculated:self];
    }
}


static void devicePlugged(void* this, io_iterator_t iterator) {
    DAStorageDrives *self = (__bridge DAStorageDrives*) this;
    IOServiceGetMatchingServices(self->masterPort,
                                 IOServiceMatching("IOBlockStorageDriver"),
                                 &self->drivelist);

    @autoreleasepool {
        io_registry_entry_t drive  = 0;  /* needs release */
        NSMutableDictionary *disks = self->disks;
        NSMutableArray *validDisks = [[NSMutableArray alloc] init];

        while ((drive = IOIteratorNext(self->drivelist))) {
            /* Obtain the name of the Device (not partition) */
            CFStringRef cfstr;
            io_registry_entry_t hdd = 0;
            CFDictionaryRef properties2 = 0;
            CFDictionaryRef statistics2 = 0;

            IORegistryEntryGetParentEntry(drive, kIOServicePlane, &hdd);
            IORegistryEntryCreateCFProperties(hdd, (CFMutableDictionaryRef*) &properties2, kCFAllocatorDefault, kNilOptions);
            statistics2 = (CFDictionaryRef) CFDictionaryGetValue(properties2, CFSTR("Device Characteristics"));
            cfstr = (CFStringRef) CFDictionaryGetValue(statistics2, CFSTR("Product Name"));

            NSString *nsstr = (__bridge NSString *) cfstr;
            [validDisks addObject:nsstr];

            if(![[disks allKeys] containsObject: nsstr]) {
                Drive* drive2 = [Drive new];
                CFDictionaryRef statistics = 0, properties = 0;
                CFNumberRef number = 0;
                uint64_t totalReadBytes = 0;
                uint64_t totalWrittenBytes = 0;

                IORegistryEntryCreateCFProperties(drive, (CFMutableDictionaryRef *) &properties, kCFAllocatorDefault, kNilOptions);
                statistics = (CFDictionaryRef) CFDictionaryGetValue(properties, CFSTR(kIOBlockStorageDriverStatisticsKey));

                if (statistics) {
                    /* Obtain the number of bytes read from the drive statistics */
                    number = (CFNumberRef) CFDictionaryGetValue(statistics, CFSTR(kIOBlockStorageDriverStatisticsBytesReadKey));
                    if (number) {
                        CFNumberGetValue(number, kCFNumberSInt64Type, &totalReadBytes);
                    }

                    /* Obtain the number of bytes written from the drive statistics */
                    number = (CFNumberRef) CFDictionaryGetValue(statistics, CFSTR(kIOBlockStorageDriverStatisticsBytesWrittenKey));
                    if (number) {
                        CFNumberGetValue(number, kCFNumberSInt64Type, &totalWrittenBytes);
                    }
                }

                [drive2 setBytesRead:totalReadBytes];
                [drive2 setBytesWrote:totalWrittenBytes];
                [disks setObject:drive2 forKey: nsstr];
                NSLog(@"%@ has been connected", nsstr);

                CFRelease(properties);
            }

            /* Release resources */
            IOObjectRelease(drive); drive = 0;
            IOObjectRelease(hdd); hdd = 0;
            CFRelease(properties2); properties2 = 0;
            
        }

        NSEnumerator* enumerator;
        NSString* str;
        enumerator = [disks keyEnumerator];
        while((str = [enumerator nextObject]) != nil) {
            if(![validDisks containsObject:str]) {
                [disks removeObjectForKey:str];
                NSLog(@"%@ has been disconnected", str);
            }
        }
    }

    if([self delegate]) {
        [[self delegate] drivesChanged: self];
    }

    IOIteratorReset(self->drivelist);
}

static void getDISKcounters(io_iterator_t drivelist, NSObject *this) {
    io_registry_entry_t drive       = 0;  /* needs release */
    UInt64          totalReadBytes  = 0;
    UInt64          totalWriteBytes = 0;
    DAStorageDrives *self = (DAStorageDrives*) this;

    while ((drive = IOIteratorNext(drivelist))) {
        CFNumberRef     number      = 0;  /* don't release */
        CFDictionaryRef properties  = 0;  /* needs release */
        CFDictionaryRef statistics  = 0;  /* don't release */
        UInt64          value       = 0;

        /* Obtain the name of the Device (not partition) */
        CFStringRef cfstr;
        io_registry_entry_t hdd = 0;
        CFDictionaryRef properties2 = 0;
        CFDictionaryRef statistics2 = 0;

        IORegistryEntryGetParentEntry(drive, kIOServicePlane, &hdd);
        IORegistryEntryCreateCFProperties(hdd, (CFMutableDictionaryRef*) &properties2, kCFAllocatorDefault, kNilOptions);
        statistics2 = (CFDictionaryRef) CFDictionaryGetValue(properties2, CFSTR("Device Characteristics"));
        cfstr = (CFStringRef) CFDictionaryGetValue(statistics2, CFSTR("Product Name"));
        NSString* nsstring = (__bridge NSString *) cfstr;

        IOObjectRelease(hdd); hdd = 0;
        CFRelease(properties2); properties2 = 0;

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

        Drive* drive = (Drive*) [self->disks objectForKey:nsstring];
        io_speed_t* io = [drive speed];
        io->ispeed = (uint32_t) (totalReadBytes - [drive bytesRead]);
        io->ospeed = (uint32_t) (totalWriteBytes - [drive bytesWrote]);
        [drive setBytesRead:totalReadBytes];
        [drive setBytesWrote:totalWriteBytes];
        totalReadBytes = totalWriteBytes = 0;
    }

    if([self delegate]) {
        [[self delegate] speedCalculated: self];
    }

    IOIteratorReset(drivelist);
}

@end