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

@interface NilBeacon : CLBeacon
@end

@implementation NilBeacon

- (NSUUID *)proximityUUID
{
    return [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
}

- (NSNumber *)major
{
    return @-1;
}

- (NSNumber *)minor
{
    return @-1;
}

- (NSString *)description
{
    return @"NilBeacon";
}

@end


#define REGIONS @{ \
    @"521BE3E0-0E18-4D39-900A-B001F5D69D3E" : @{ \
        @"identifier" : @"H&M: Fernöstliche Eleganz", \
        @"notification" : @"Haben Sie das H&M Plakat gesehen? Entdecken Sie die schlichte Eleganz des fernen Ostens in unseren Geschäften. Hier mehr erfahren…", \
        @"url" : @"http://www.hm.com/ch/eastern-elegance", \
    }, \
    @"4D0C95A7-2474-4891-BA1E-59BFFA99D71F" : @{ \
        @"identifier" : @"H&M: Der Sommer kommt", \
        @"notification" : @"Haben Sie das H&M Plakat gesehen? Der Sommer kommt! Hier mehr erfahren…", \
        @"url" : @"http://www.hm.com/ch/summer-starts-now", \
    }, \
}

@interface AppDelegate () <CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager *locationManager;

@property (strong, nonatomic) NSMutableDictionary *currentBeacons;
@property (strong, nonatomic) NSMutableArray *closestBeaconHistory;
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

- (NSMutableArray *)closestBeaconHistory
{
    if (!_closestBeaconHistory) {
        _closestBeaconHistory = [NSMutableArray array];
    }
    return _closestBeaconHistory;
}

- (NSArray *)regionsToMonitor
{
    NSMutableArray *regions = [NSMutableArray array];
    
    for (NSString *uuidString in REGIONS) {
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
        NSString *identifier = REGIONS[uuidString][@"identifier"];
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
    NSString *uuid = notification.userInfo[@"regionUUID"];
    if (uuid) {
        NSURL *url = [NSURL URLWithString:REGIONS[uuid][@"url"] ];
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
    // find the currently selected beacon
    CLBeacon *previouslySelectedBeacon;
    for (CLRegion *region in self.currentBeacons) {
        for (CLBeacon *beacon in self.currentBeacons[region]) {
            if ([beacon.proximityUUID isEqual:self.selectedBeacon.proximityUUID] &&
                [beacon.major isEqual:self.selectedBeacon.major] &&
                [beacon.minor isEqual:self.selectedBeacon.minor]) {
                previouslySelectedBeacon = beacon;
                break;
            }
        }
    }
    
    // find the closest beacon
    CLBeacon *closestBeacon;
    if (previouslySelectedBeacon.proximity != CLProximityUnknown) {
        closestBeacon = previouslySelectedBeacon;
    }
    for (CLRegion *region in self.currentBeacons) {
        for (CLBeacon *beacon in self.currentBeacons[region]) {
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
    
    // keep history of closest beacons
    int HISTORY_SIZE = 4;
    if (closestBeacon) {
        [self.closestBeaconHistory addObject:closestBeacon];
    } else {
        NilBeacon *nilBeacon = [[NilBeacon alloc] init];
        [self.closestBeaconHistory addObject:nilBeacon];
    }
    
    while (self.closestBeaconHistory.count > HISTORY_SIZE) {
        [self.closestBeaconHistory removeObjectAtIndex:0];
    }
    
    // check if the closest beacon was constant
    BOOL closestBeaconWasConstant = YES;
    if (self.closestBeaconHistory.count) {
        for(int i = 0; i < self.closestBeaconHistory.count-1; i++) {
            CLBeacon *beacon1 = self.closestBeaconHistory[i];
            CLBeacon *beacon2 = self.closestBeaconHistory[i+1];
            closestBeaconWasConstant = closestBeaconWasConstant && [beacon1.proximityUUID isEqual:beacon2.proximityUUID] &&
                                                                   [beacon1.major isEqual:beacon2.major] &&
                                                                   [beacon1.minor isEqual:beacon2.minor];
        }
    }
        
    // if the last closest beacons are the same...
    if (closestBeaconWasConstant) {
        // ...select the closest beacon
        self.selectedBeacon = closestBeacon;
        
        // if the selected beacon has changed, react...
        if (self.selectedBeacon != previouslySelectedBeacon) {
            NSLog(@"selected beacon has changed to %@", self.selectedBeacon);
            if (self.selectedBeacon) {
                CLBeaconRegion *beaconRegion;
                for (CLBeaconRegion *region in self.currentBeacons) {
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
}

#pragma mark - Notification handling

- (void)notifyAboutRegion:(CLBeaconRegion *)region
{
    // keep an array of region identifiers for which notifications were already triggered
    // in the user defaults...
    NSArray *regionIdentifiersWithNotification = [NSUserDefaults.standardUserDefaults valueForKey:@"regionIdentifiersWithNotification"];
    if ([regionIdentifiersWithNotification containsObject:region.identifier]) {
        return;
    }
    [NSUserDefaults.standardUserDefaults setValue:[regionIdentifiersWithNotification arrayByAddingObject:region.identifier] forKey:@"regionIdentifiersWithNotification"];
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody   = REGIONS[region.proximityUUID.UUIDString][@"notification"];
    notification.alertAction = @"Show";
    notification.soundName   = UILocalNotificationDefaultSoundName;
    notification.userInfo    = @{@"regionUUID" : region.proximityUUID.UUIDString};
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
