//
//  FKResponseParser.h
//  NOAA Forecast Kit
//
//  Created by Joseph Chen on 1/8/14.
//  Copyright (c) 2014 Joseph Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FKResponseParser;
@protocol FKResponseParserDelegate <NSObject>

- (void)responseParser:(FKResponseParser *)parser parsedForecasts:(NSArray *)forecasts;
- (void)responseParser:(FKResponseParser *)parser didFailWithError:(NSError *)error;

@end

@interface FKResponseParser : NSObject
@property (weak, nonatomic) id<FKResponseParserDelegate> delegate;

- (BOOL)parseResponse:(NSData *)responseData;
@end

@interface FKSchemaItem : NSObject
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *value;
@end

@interface FKSchemaAttribute : FKSchemaItem
@end

@interface FKSchemaElement : FKSchemaItem

@property (weak, nonatomic) FKSchemaElement *parent;
@property (nonatomic, readonly) NSMutableArray *children;
@property (nonatomic, readonly) NSMutableSet *attributes;

- (FKSchemaElement *)childWithName:(NSString *)elementName;
- (FKSchemaElement *)childWithName:(NSString *)elementName attribute:(NSString *)attributeName attributeValue:(NSString *)attributeValue;
- (FKSchemaAttribute *)attributeWithName:(NSString *)attributeName;
- (NSInteger)countOfChildren;
- (NSInteger)countOfAttributes;

@end
