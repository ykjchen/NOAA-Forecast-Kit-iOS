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

/*!
 * Singleton for handling all requests from your app.
 */
+ (FKDataManager *)sharedManager;

/*!
 * Request forecasts for device's current location. Returns NO if the request could not start, with a description of the error in preRequestError. Returns YES if the request begins. If the request completes successfully, an array of FKForecast objects is passed to the completion handler. If the request fails, the forecast array is nil and the error description is passed to the completion handler.
 */
- (BOOL)requestForecastsForCurrentLocationWithCompletion:(void (^)(NSArray *forecasts, NSError *error))completionHandler
                                                   error:(NSError *__autoreleasing *)preRequestError;

/*!
 * Request forecasts for a specific zipcode. Returns NO if the request could not start, with a description of the error in preRequestError. Returns YES if the request begins. If the request completes successfully, an array of FKForecast objects is passed to the completion handler. If the request fails, the forecast array is nil and the error description is passed to the completion handler.
 */
- (BOOL)requestForecastsForZipcode:(NSString *)zipcode
                        completion:(void (^)(NSArray *forecasts, NSError *error))completionHandler
                             error:(NSError *__autoreleasing *)preRequestError;

/*!
 * Get location information (city, state) for a zipcode. Returns nil if the zipcode passed in is not recognized.
 */
- (FKLocation *)locationForZipcode:(NSString *)zipcode;

@end
