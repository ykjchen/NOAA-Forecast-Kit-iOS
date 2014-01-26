//
//  FKResponseParser.h
//  NOAA Forecast Kit
//
//  Created by Joseph Chen on 1/8/14.
//  Copyright (c) 2014 Joseph Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FKResponseParser, FKForecast;
@protocol FKResponseParserDelegate <NSObject>
- (void)responseParser:(FKResponseParser *)parser parsedForecasts:(NSArray *)forecasts;
- (void)responseParser:(FKResponseParser *)parser didFailWithError:(NSError *)error;
@end

@protocol FKResponseParserDataSource <NSObject>
@required
- (FKForecast *)forecastForLatitude:(float)latitude longitude:(float)longitude date:(NSDate *)date;
@end

@interface FKResponseParser : NSObject
@property (unsafe_unretained, nonatomic) id<FKResponseParserDelegate> delegate;
@property (unsafe_unretained, nonatomic) id<FKResponseParserDataSource> dataSource;
- (BOOL)parseResponse:(NSData *)responseData;
@end

@interface FKSchemaItem : NSObject
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *value;
@end

@interface FKSchemaAttribute : FKSchemaItem
@end

@interface FKSchemaElement : FKSchemaItem
@property (unsafe_unretained, nonatomic) FKSchemaElement *parent;
@property (nonatomic, readonly) NSMutableArray *children;
@property (nonatomic, readonly) NSMutableSet *attributes;
- (FKSchemaElement *)childWithName:(NSString *)elementName;
- (FKSchemaElement *)childWithName:(NSString *)elementName attribute:(NSString *)attributeName attributeValue:(NSString *)attributeValue;
- (FKSchemaAttribute *)attributeWithName:(NSString *)attributeName;
- (NSInteger)countOfChildren;
- (NSInteger)countOfAttributes;
@end
