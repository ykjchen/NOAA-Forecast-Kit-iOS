//
//  FKForecast.h
//  NOAA Forecast Kit
//
//  Created by Joseph Chen on 1/7/14.
//  Copyright (c) 2014 Joseph Chen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface FKForecast : NSManagedObject

@property (nonatomic, retain) NSString * summary;
@property (nonatomic, retain) NSDate * startDate;
@property (nonatomic, retain) NSDate * fetchDate;
@property (nonatomic, retain) NSDate * endDate;
@property (nonatomic, retain) NSNumber * probabilityOfPrecipitation;
@property (nonatomic, retain) NSNumber * minimumTemperature;
@property (nonatomic, retain) NSNumber * maximumTemperature;
@property (nonatomic, retain) NSString * temperatureUnits;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSNumber * longitude;

@end
