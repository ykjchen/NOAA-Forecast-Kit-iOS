//
//  FKStore.h
//  NOAA Forecast Kit
//
//  Created by Joseph Chen on 1/7/14.
//  Copyright (c) 2014 Joseph Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FKLocation, FKForecast;
/*!
 * Manages the zipcode and forecast database.
 */
@interface FKStore : NSObject

/*!
 * Save changes to database. A return value of YES indicates the save was successful.
 */
- (BOOL)saveContext;

/*!
 * Get coordinates for zipcode.
 */
- (FKLocation *)locationForZipcode:(NSString *)zipcode;

/*!
 * Get forecast object for location.
 */
- (FKForecast *)forecastForLatitude:(float)latitude longitude:(float)longitude date:(NSDate *)date;

@end
