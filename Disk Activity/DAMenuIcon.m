//
//  DAMenuIcon.m
//  Disk Activity
//
//  Created by Melchor Garau Madrigal on 19/11/13.
//  Copyright (c) 2013 Melchor Garau Madrigal. All rights reserved.
//

#import "DAMenuIcon.h"

@implementation DAMenuIcon
DAMenuIcon *this;
DAImageView *v;
DAStorageDrives *sto;
NSString* selectedDevice;

@synthesize graphImage = anImage;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
}

- (void)awakeFromNib {
    this = self;
    v = [[DAImageView alloc] init];
    sto = [[DAStorageDrives alloc] init];
    [sto setDelegate:this];

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

    [v setMenu:menu];
    v.statusItem = statusItem;

    //Select stored device or get the first one
    selectedDevice = [DAMenuIcon getPreference:@"SelectedDisk"];
    if(selectedDevice == nil) {
        selectedDevice = [[sto drives] firstObject];
    }
    [self setDisksToMenu];
}

- (void) speedCalculated:(DAStorageDrives*) this {
    [self updateDiskUsage:this];
}

- (void) drivesChanged:(DAStorageDrives*) this {
    [self setDisksToMenu];
}

- (IBAction)updateDiskUsage:(id)sender {
    io_speed_t io = *[sto speedForDevice:selectedDevice];

    float imgWidth = 60.0;
         if(_text && !_icon) imgWidth = 44;
    else if(!_text && _icon) imgWidth = 16;
    NSString *readS = [NSString alloc], *writeS = [NSString alloc];
    anImage = [[NSImage alloc] initWithSize:NSMakeSize(imgWidth, 21.0)];
    NSColor *green = [NSColor colorWithRed:10.0/255.0 green:160/255.0 blue:15/255.0 alpha:1];
    NSColor *red =   [NSColor colorWithRed:255/255.0  green:10/230.0  blue:15/255.0 alpha:1];

    if(_text) {
        if(io.ispeed < 1000)
            readS = [readS initWithFormat:@"%uB/s", io.ispeed];
        else if(io.ispeed/1000 < 1000)
            readS = [readS initWithFormat:@"%uKB/s", io.ispeed/1000];
        else if(io.ispeed/1000/1000 < 1000)
            readS = [readS initWithFormat:@"%.1fMB/s", io.ispeed/1000.0/1000.0];
        else if(io.ispeed/1000/1000 > 1000)
            readS = [readS initWithFormat:@"%.1GB/s", io.ispeed/1000.0/1000.0/1000.0];

        if(io.ospeed < 1000)
            writeS = [writeS initWithFormat:@"%uB/s", io.ospeed];
        else if(io.ospeed/1000 < 1000)
            writeS = [writeS initWithFormat:@"%uKB/s", io.ospeed/1000];
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
        [readS drawInRect:NSMakeRect(_icon ? 18 : 0, 12, [anImage size].width, 10) withAttributes:attributes];
        //Write speed
        attributes = [NSDictionary dictionaryWithObjectsAndKeys:f,
                      NSFontAttributeName, red,
                      NSForegroundColorAttributeName, style,
                      NSParagraphStyleAttributeName, nil];
        [writeS drawInRect:NSMakeRect(_icon ? 18 : 0, 2, [anImage size].width, 10) withAttributes:attributes];
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
        for(int i = 0; i < 6; i++) {
            [[NSBezierPath bezierPathWithRect:NSMakeRect(2, 2 + 3*i, 6, 1.7)] fill];
            [[NSBezierPath bezierPathWithRect:NSMakeRect(9, 2 + 3*i, 6, 1.7)] fill];
        }

        //Write bar
        [green setFill];
        for(int i = 0; i < 6; i++) {
            if(3.6*(i+1) < read)
                [[NSBezierPath bezierPathWithRect:NSMakeRect(2, 2 + 3*i, 6, 1.7)] fill];
        }

        //Red bar
        [red setFill];
        for(int i = 0; i < 6; i++) {
            if(3.6*(i+1) < write)
                [[NSBezierPath bezierPathWithRect:NSMakeRect(9, 2 + 3*i, 6, 1.7)] fill];
        }

        [anImage unlockFocus];
    }

    //Set final image
    [v setImage:anImage];
    [v setFrame:NSMakeRect(0, 0, [anImage size].width, [anImage size].height+2)];
    [statusItem setView:v];
}

- (IBAction)quit:(id)sender {
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
    if([disk state] == NSOffState) {
        NSEnumerator* en = [[menu itemArray] objectEnumerator];
        NSMenuItem* item;
        while((item = [en nextObject]) != nil) {
            [item setState:NSOffState];
        }

        [disk setState:NSOnState];
        [DAMenuIcon setPreference:key withKey:@"SelectedDisk"];
        selectedDevice = key;
    }
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
    NSEnumerator *nsenum = [[sto drives] objectEnumerator];
    NSString *key;
    NSMenu *diskMenu = [[NSMenu alloc] init];
    while((key = [nsenum nextObject])) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:key action:@selector(diskElementClick:) keyEquivalent:@""];
        [item setTarget:self];
        [item setState: [selectedDevice isEqualToString:key]];
        [diskMenu addItem:item];
    }
    [menu setSubmenu:diskMenu forItem:[menu itemWithTitle:@"Disks"]];
}

@end