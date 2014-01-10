//
//  FKForecastRequester.h
//  NOAA Forecast Kit
//
//  Created by Joseph Chen on 1/7/14.
//  Copyright (c) 2014 Joseph Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FKLocation, FKForecastRequester;

@protocol FKForecastRequesterDelegate <NSObject>

- (void)forecastRequester:(FKForecastRequester *)requester receivedResponse:(NSData *)responseData;
- (void)forecastRequester:(FKForecastRequester *)requester didFailWithError:(NSError *)error;

@end

@interface FKForecastRequester : NSObject

@property (unsafe_unretained, nonatomic) id<FKForecastRequesterDelegate> delegate;

- (BOOL)requestForecastsForLatitude:(float)latitude
                          longitude:(float)longitude
                              error:(NSError *__autoreleasing *)preRequestError;

@end

@interface FKURLConnection : NSURLConnection

@property (strong, nonatomic) NSMutableData *data;

@end

