//
//  DAStorageDrives.h
//  Disk Activity
//
//  Created by Melchor Garau Madrigal on 9/4/16.
//  Copyright © 2016 Melchor Garau Madrigal. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct io {
    uint32_t ispeed;
    uint32_t ospeed;
} io_speed_t;

@class DAStorageDrives;

@protocol DAStorageDrivesDelegate <NSObject>

- (void) speedCalculated: (DAStorageDrives*) this;
- (void) drivesChanged: (DAStorageDrives*) this;

@end

@interface DAStorageDrives : NSObject

@property id delegate;

- (const io_speed_t*) speedForDevice: (NSString*) device;
- (NSArray*) drives;

@end
