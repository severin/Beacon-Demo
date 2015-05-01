//
//  AppDelegate.m
//  Beacon Demo
//
//  Created by Severin Schoepke on 29/04/15.
//  Copyright (c) 2015 Shortcut Media AG. All rights reserved.
//

#import "AppDelegate.h"

#import "MainViewController.h"
#import "WebViewController.h"

#import <CoreLocation/CoreLocation.h>

#define REGIONS @{ \
    @"H&M Plakat Demo" : @{ \
        @"uuid" : @"521BE3E0-0E18-4D39-900A-B001F5D69D3E", \
        @"notification" : @"Haben Sie das H&M Plakat gesehen? Entdecken Sie die schlichte Eleganz des fernen Ostens in unseren Geschäften. Hier mehr erfahren", \
        @"url" : @"http://www.hm.com/ch/eastern-elegance", \
    }, \
    @"Shortcut Blue" : @{ \
        @"uuid" : @"4D0C95A7-2474-4891-BA1E-59BFFA99D71F", \
        @"notification" : @"Ein bläuliches Beacon ist in der Nähe…", \
        @"url" : @"https://en.wikipedia.org/wiki/Blue", \
}, \
}

@interface AppDelegate () <CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager *locationManager;

@property (strong, nonatomic) NSMutableDictionary *currentBeacons;
@property (strong, nonatomic) CLBeacon *selectedBeacon;

@property (strong, nonatomic) MainViewController *mainViewController;
@property (strong, nonatomic) WebViewController *webViewController;

@end


@implementation AppDelegate

- (NSMutableDictionary *)currentBeacons
{
    if (!_currentBeacons) {
        _currentBeacons = [NSMutableDictionary dictionary];
    }
    return _currentBeacons;
}

- (NSArray *)regionsToMonitor
{
    NSMutableArray *regions = [NSMutableArray array];
    
    for (NSString *identifier in REGIONS) {
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:REGIONS[identifier][@"uuid"]];
        CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:identifier];
        [regions addObject:region];
    }
    
    return regions;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [self resetNotifications];
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    // needs "always" auth for background monitoring...
    [self.locationManager requestAlwaysAuthorization];
    
    // needs to prompt for notifications...
    UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
    
    // cleanup: remove all monitorings to clean out legacy monitorings
    for (CLBeaconRegion *region in self.locationManager.monitoredRegions) {
        [self.locationManager stopMonitoringForRegion:region];
    }
    
    // start monitoring for all regions
    for (CLBeaconRegion *region in self.regionsToMonitor) {
        [self.locationManager requestStateForRegion:region];
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self.mainViewController = [storyboard instantiateViewControllerWithIdentifier:@"mainViewController"];
    self.webViewController  = [storyboard instantiateViewControllerWithIdentifier:@"webViewController"];
    
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = self.mainViewController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    NSString *identifier = notification.userInfo[@"regionIdentifier"];
    if (identifier) {
        NSURL *url = [NSURL URLWithString:REGIONS[identifier][@"url"] ];
        [self showWebsite:url];
    }
    
    [self resetNotifications];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"LM error: %ld - %@", (long)error.code, error.debugDescription);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    for (CLBeaconRegion *region in self.regionsToMonitor) {
        [self.locationManager requestStateForRegion:region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    NSLog(@"LM did determine state of region %@: %ld", region.identifier, (long)state);
    
    if (![manager.monitoredRegions containsObject:region]) {
        NSLog(@"LM starts monitoring region %@", region.identifier);
        [self.locationManager startMonitoringForRegion:region];
    }
    
    if (state == CLRegionStateInside) {
        [self locationManager:manager didEnterRegion:region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    NSLog(@"LM did enter region %@", region.identifier);
    
    if ([region.class isSubclassOfClass:CLBeaconRegion.class]) {
        [self.currentBeacons setObject:@[] forKey:region];
        [manager startRangingBeaconsInRegion:(CLBeaconRegion *)region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    NSLog(@"LM did leave region %@", region.identifier);
    
    if ([region.class isSubclassOfClass:CLBeaconRegion.class]) {
        [manager stopRangingBeaconsInRegion:(CLBeaconRegion *)region];
        [self.currentBeacons removeObjectForKey:region];
        [self selectBeacon];
    }
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
    NSLog(@"LM did fail to monitor region %@: %ld - %@", region.identifier, (long)error.code, error.debugDescription);
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    NSLog(@"LM did range beacons in region %@", region.identifier);
    
    [self.currentBeacons setObject:beacons forKey:region];
    [self selectBeacon];
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
{
    NSLog(@"LM did fail to range in region %@", region.identifier);
}

#pragma mark - Beacon tracking

- (void)selectBeacon
{
    // find the currently selected and closest beacon
    CLBeacon *previouslySelectedBeacon, *closestBeacon;
    for (CLRegion *region in self.currentBeacons) {
        for (CLBeacon *beacon in self.currentBeacons[region]) {
            if ([beacon.proximityUUID isEqual:self.selectedBeacon.proximityUUID] &&
                [beacon.major isEqual:self.selectedBeacon.major] &&
                [beacon.minor isEqual:self.selectedBeacon.minor]) {
                previouslySelectedBeacon = beacon;
            }
            
            if (beacon.proximity == CLProximityUnknown) {
                continue;
            }
            
            if (!closestBeacon) {
                closestBeacon = beacon;
            } else if (closestBeacon.proximity == CLProximityFar) {
                if (beacon.proximity == CLProximityNear || beacon.proximity == CLProximityImmediate) {
                    closestBeacon = beacon;
                }
            } else if (closestBeacon.proximity == CLProximityNear) {
                if (beacon.proximity == CLProximityImmediate) {
                    closestBeacon = beacon;
                }
            }
        }
    }
    
    // select the closest beacon
    self.selectedBeacon = closestBeacon;
    
    // if the selected beacon has changed, react...
    if (self.selectedBeacon != previouslySelectedBeacon) {
        NSLog(@"selected beacon has changed to %@", self.selectedBeacon);
        if (self.selectedBeacon) {
            CLRegion *beaconRegion;
            for (CLRegion *region in self.currentBeacons) {
                if ([self.currentBeacons[region] containsObject:self.selectedBeacon]) {
                    beaconRegion = region;
                }
            }
            [self notifyAboutRegion:beaconRegion];
        } else {
            [self showWebsite:nil];
        }
    }
}

#pragma mark - Notification handling

- (void)notifyAboutRegion:(CLRegion *)region
{
    // keep an array of region identifiers for which notifications were already triggered
    // in the user defaults...
    NSArray *regionIdentifiersWithNotification = [NSUserDefaults.standardUserDefaults valueForKey:@"regionIdentifiersWithNotification"];
    if ([regionIdentifiersWithNotification containsObject:region.identifier]) {
        return;
    }
    [NSUserDefaults.standardUserDefaults setValue:[regionIdentifiersWithNotification arrayByAddingObject:region.identifier] forKey:@"regionIdentifiersWithNotification"];
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody   = REGIONS[region.identifier][@"notification"];
    notification.alertAction = @"Show";
    notification.soundName   = UILocalNotificationDefaultSoundName;
    notification.userInfo    = @{@"regionIdentifier" : region.identifier};
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    
    [UIApplication sharedApplication].applicationIconBadgeNumber++;
}

- (void)resetNotifications
{
    [NSUserDefaults.standardUserDefaults setValue:@[] forKey:@"regionIdentifiersWithNotification"];
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
}


#pragma mark - Web view handling

- (void)showWebsite:(NSURL *)url
{
    if (url) {
        if (!self.mainViewController.presentedViewController) {
            [self.mainViewController presentViewController:self.webViewController animated:YES completion:nil];
        }
        self.webViewController.url = url;
    } else {
        if (self.mainViewController.presentedViewController) {
            [self.mainViewController dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

@end
