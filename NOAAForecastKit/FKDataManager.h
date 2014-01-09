//
//  FKDataManager.h
//  NOAA Forecast Kit
//
//  Created by Joseph Chen on 1/7/14.
//  Copyright (c) 2014 Joseph Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct
{
    float latitude, longitude;
} FKGeoposition;

@class FKForecast, FKLocation;

@interface FKDataManager : NSObject

+ (FKDataManager *)sharedManager;

- (BOOL)requestForecastsForCurrentLocationWithCompletion:(void (^)(NSArray *forecasts, NSError *error))completionHandler
                                                   error:(NSError *__autoreleasing *)preRequestError;
- (BOOL)requestForecastsForZipcode:(NSString *)zipcode
                        completion:(void (^)(NSArray *forecasts, NSError *error))completionHandler
                             error:(NSError *__autoreleasing *)preRequestError;

- (FKForecast *)forecastForGeoposition:(FKGeoposition)geoposition date:(NSDate *)date;
- (FKLocation *)locationForZipcode:(NSString *)zipcode;

@end
