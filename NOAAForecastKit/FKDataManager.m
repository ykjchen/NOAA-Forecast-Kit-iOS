//
//  FKDataManager.m
//  NOAA Forecast Kit
//
//  Created by Joseph Chen on 1/7/14.
//  Copyright (c) 2014 Joseph Chen. All rights reserved.
//

#import "FKDataManager.h"

// Location
#import <CoreLocation/CoreLocation.h>

// Model
#import "FKStore.h"
#import "FKForecast.h"
#import "FKLocation.h"

// NOAA request manager
#import "FKForecastRequester.h"

// XML parser
#import "FKResponseParser.h"

static FKDataManager *_sharedManager = nil;

@interface FKDataManager () <FKForecastRequesterDelegate, FKResponseParserDelegate, FKResponseParserDataSource, CLLocationManagerDelegate>

@property (strong, nonatomic) FKStore *store;
@property (strong, nonatomic) FKForecastRequester *forecastRequester;
@property (strong, nonatomic) FKResponseParser *responseParser;
@property (strong, nonatomic) CLLocationManager *locationManager;

// if ![CLLocationManager significantLocationChangeMonitoringAvailable]
// update location only every so often to save power
@property (strong, nonatomic) NSTimer *locationUpdateTimer;

@property (strong, nonatomic) void (^completionHandler)(NSArray *, NSError *);

@end

NSTimeInterval const FKDataManagerLocationUpdateInterval = 300.0;

@implementation FKDataManager

#pragma mark - Singleton
+ (FKDataManager *)sharedManager
{
    if (nil != _sharedManager) {
        return _sharedManager;
    }
    
    // www.johnwordsworth.com/2010/04/iphone-code-snippet-the-singleton-pattern
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[super allocWithZone:NULL] init];
    });
    return _sharedManager;
}

// Prevent creation of additional instances
+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedManager];
}

- (id)init
{
    if (_sharedManager) {
        return _sharedManager;
    }
    
    self = [super init];
    
    if (self) {
        [self.locationManager startUpdatingLocation];
    }
    
    return self;
}

#if !__has_feature(objc_arc)
- (id)retain
{
    return self;
}

- (oneway void)release
{
    // Do nothing
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;
}
#endif

#pragma mark - Accessors

- (FKStore *)store
{
    if (!_store) {
        _store = [[FKStore alloc] init];
    }
    return _store;
}

- (FKForecastRequester *)forecastRequester
{
    if (!_forecastRequester) {
        _forecastRequester = [[FKForecastRequester alloc] init];
        _forecastRequester.delegate = self;
    }
    return _forecastRequester;
}

- (FKResponseParser *)responseParser
{
    if (!_responseParser) {
        _responseParser = [[FKResponseParser alloc] init];
        _responseParser.delegate = self;
        _responseParser.dataSource = self;
    }
    return _responseParser;
}

- (CLLocationManager *)locationManager
{
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
    }
    return _locationManager;
}

- (void)startUpdatingLocation
{
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined ||
        [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized) {
        if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
            [_locationManager startMonitoringSignificantLocationChanges];
        } else {
            [_locationManager startUpdatingLocation];
        }
    }
}

#pragma mark - Error

- (NSError *)errorWithMessage:(NSString *)message
{
    NSDictionary *errorDetail = [NSDictionary dictionaryWithObject:message
                                                            forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"FKDataManagerDomain"
                               code:0
                           userInfo:errorDetail];
}

- (void)failWithError:(NSError *)error
{
    if (self.completionHandler) {
        self.completionHandler(nil, error);
        self.completionHandler = nil;
    }
}

#pragma mark - Public

- (BOOL)requestForecastsForGeoposition:(FKGeoposition)geoposition
                            completion:(void (^)(NSArray *, NSError *))completionHandler
                                 error:(NSError *__autoreleasing *)preRequestError
{
    if (!completionHandler) {
        *preRequestError = [self errorWithMessage:@"A completion handler is required."];
       return NO;
    }
    
    if (self.completionHandler) {
        *preRequestError = [self errorWithMessage:@"Requests can be processed only one at a time."];
        return NO;
    }
    
#if DEBUG
    NSLog(@"Requesting forecast for latitude:%f longitude:%f", geoposition.latitude, geoposition.longitude);
#endif

    
    BOOL requested = [self.forecastRequester requestForecastsForLatitude:geoposition.latitude
                                                               longitude:geoposition.longitude
                                                                   error:preRequestError];
    if (requested) {
        self.completionHandler = completionHandler;
    }
    return requested;
}

- (BOOL)requestForecastsForCurrentLocationWithCompletion:(void (^)(NSArray *, NSError *))completionHandler
                                                   error:(NSError *__autoreleasing *)preRequestError
{
    if (![CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized) {
        *preRequestError = [self errorWithMessage:@"This app does not have permission to check your location."];
        return NO;
    }
    
    CLLocation *location = self.locationManager.location;
    
    FKGeoposition geoposition;
    geoposition.latitude = location.coordinate.latitude;
    geoposition.longitude = location.coordinate.longitude;
    
    return [self requestForecastsForGeoposition:geoposition
                                     completion:completionHandler
                                          error:preRequestError];
}

- (BOOL)requestForecastsForZipcode:(NSString *)zipcode
                        completion:(void (^)(NSArray *, NSError *))completionHandler
                             error:(NSError *__autoreleasing *)preRequestError
{
    FKLocation *location = [self.store locationForZipcode:zipcode];
    if (!location) {
        *preRequestError = [self errorWithMessage:[NSString stringWithFormat:@"Zipcode %@ not found in database.", zipcode]];
        return NO;
    }
    
    FKGeoposition geoposition;
    geoposition.latitude = location.latitude.floatValue;
    geoposition.longitude = location.longitude.floatValue;
    return [self requestForecastsForGeoposition:geoposition
                                     completion:completionHandler
                                          error:preRequestError];
}

- (FKLocation *)locationForZipcode:(NSString *)zipcode
{
    return [self.store locationForZipcode:zipcode];
}

#pragma mark - FKForecastRequesterDelegate

- (void)forecastRequester:(FKForecastRequester *)requester didFailWithError:(NSError *)error
{
    [self failWithError:error];
}

- (void)forecastRequester:(FKForecastRequester *)requester receivedResponse:(NSData *)responseData
{
    if (![self.responseParser parseResponse:responseData]) {
        [self failWithError:[self errorWithMessage:@"Could not start parser."]];
    }
}

#pragma mark - FKResponseParserDataSource

- (FKForecast *)forecastForLatitude:(float)latitude longitude:(float)longitude date:(NSDate *)date
{
    return [self.store forecastForLatitude:latitude longitude:longitude date:date];
}

#pragma mark - FKResponseParserDelegate

- (void)responseParser:(FKResponseParser *)parser didFailWithError:(NSError *)error
{
    [self failWithError:error];
}

- (void)responseParser:(FKResponseParser *)parser parsedForecasts:(NSArray *)forecasts
{
    if (self.completionHandler) {
        self.completionHandler(forecasts, nil);
        self.completionHandler = nil;
        
        [self.store saveContext];
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorized) {
        [self startUpdatingLocation];
    }
}

// >= iOS6
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{    
    // got location, save some power
    [self.locationManager stopUpdatingLocation];
    
    // update location again after some time
    if (self.locationUpdateTimer) {
        [self.locationUpdateTimer invalidate];
        self.locationUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:FKDataManagerLocationUpdateInterval
                                                                    target:self
                                                                  selector:@selector(startUpdatingLocation)
                                                                  userInfo:nil
                                                                   repeats:NO];
    }
}

// <= iOS6
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    [self locationManager:manager didUpdateLocations:@[newLocation]];
}

@end
