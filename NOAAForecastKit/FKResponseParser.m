
//
//  FKResponseParser.m
//  NOAA Forecast Kit
//
//  Created by Joseph Chen on 1/8/14.
//  Copyright (c) 2014 Joseph Chen. All rights reserved.
//

#import "FKResponseParser.h"

#import "FKForecast.h"

@interface FKResponseParser () <NSXMLParserDelegate>

@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) NSXMLParser *parser;

@property (nonatomic) float latitude;
@property (nonatomic) float longitude;
@property (strong, nonatomic) NSMutableArray *forecasts;

@property (strong, nonatomic) FKSchemaElement *currentElement;
@property (strong, nonatomic) FKSchemaElement *currentParentElement;
@property (strong, nonatomic) NSMutableString *currentElementValue;
@property (strong, nonatomic) FKSchemaElement *rootElement;

@end

@implementation FKResponseParser

#if !__has_feature(objc_arc)
- (void)dealloc
{
    [_dateFormatter release];
    [_parser release];
    [_forecasts release];
    [_currentElement release];
    [_currentParentElement release];
    [_currentElementValue release];
    [_rootElement release];
    
    [super dealloc];
}
#endif

- (NSDateFormatter *)dateFormatter
{
    if (!_dateFormatter) {
        // https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/DataFormatting/Articles/dfDateFormatting10_4.html#//apple_ref/doc/uid/TP40002369-SW1
        _dateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        _dateFormatter.locale = enUSPOSIXLocale;
        _dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss";
        
#if !__has_feature(objc_arc)
        [enUSPOSIXLocale release];
#endif
    }
    return _dateFormatter;
}

- (NSError *)errorWithMessage:(NSString *)message
{
    NSDictionary *errorDetail = [NSDictionary dictionaryWithObject:message
                                                            forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"FKResponseParserDomain"
                               code:0
                           userInfo:errorDetail];
}

- (void)cleanUp
{
    self.parser = nil;
    [self.forecasts removeAllObjects];
    self.currentElement = nil;
    self.currentElementValue = nil;
    self.currentParentElement = nil;
    self.rootElement = nil;
}

- (void)failWithError:(NSError *)error
{
    if (self.delegate &&
        [self.delegate conformsToProtocol:@protocol(FKResponseParserDelegate)]
        && [self.delegate respondsToSelector:@selector(responseParser:didFailWithError:)]) {
        [self.delegate responseParser:self didFailWithError:error];
    }
    
    [self cleanUp];
}

- (void)reportForecasts
{
    if (self.delegate &&
        [self.delegate conformsToProtocol:@protocol(FKResponseParserDelegate)] &&
        [self.delegate respondsToSelector:@selector(responseParser:parsedForecasts:)]) {
        [self.delegate responseParser:self parsedForecasts:[NSArray arrayWithArray:self.forecasts]];
    }
    
    [self cleanUp];
}

- (NSMutableArray *)forecasts
{
    if (!_forecasts) {
        _forecasts = [[NSMutableArray alloc] initWithCapacity:7];
    }
    return _forecasts;
}

- (BOOL)addForecastWithDate:(NSDate *)date
{
    if (self.dataSource && [self.dataSource conformsToProtocol:@protocol(FKResponseParserDataSource)] && [self.dataSource respondsToSelector:@selector(forecastForLatitude:longitude:date:)]) {
        FKForecast *forecast = [self.dataSource forecastForLatitude:self.latitude
                                                          longitude:self.longitude
                                                               date:date];
        forecast.fetchDate = [NSDate date];
        [self.forecasts addObject:forecast];
        return YES;
    }
    
    return NO;
}

- (FKForecast *)forecastAtIndex:(NSInteger)index
{
    NSAssert(index < _forecasts.count, @"Attempting to access forecast at index: %i", index);
    
    return [_forecasts objectAtIndex:index];
}

- (void)setGeopositionFromDataElement:(FKSchemaElement *)dataElement
{
    FKSchemaElement *location = [dataElement childWithName:@"location"];
    FKSchemaElement *point = [location childWithName:@"point"];
    
    self.latitude = [[[point attributeWithName:@"latitude"] value] floatValue];
    self.longitude = [[[point attributeWithName:@"longitude"] value] floatValue];
}

- (void)setTimeLayoutFromDataElement:(FKSchemaElement *)dataElement
{
    FKSchemaElement *timeLayout = [dataElement childWithName:@"time-layout"];
    FKSchemaElement *layoutKey = [timeLayout childWithName:@"layout-key"];
    if (![layoutKey.value isEqualToString:@"k-p24h-n7-1"]) {
        [self failWithError:[self errorWithMessage:[NSString stringWithFormat:@"Found wrong time-layout element (%@).", layoutKey.value]]];
        return;
    }
    
    NSInteger forecastIndex = 0;
    for (FKSchemaElement *child in timeLayout.children) {
        if ([child.name isEqualToString:@"start-valid-time"]) {
            NSDate *date = [self dateFromDWMLDate:child.value];
            if (![self addForecastWithDate:date]) {
                [self failWithError:[self errorWithMessage:@"No valid dataSource found."]];
                return;
            }
        } else if ([child.name isEqualToString:@"end-valid-time"]) {
            FKForecast *forecast = [self forecastAtIndex:forecastIndex];
            forecast.endDate = [self dateFromDWMLDate:child.value];
            forecastIndex ++;
        }
    }
}

- (void)setTemperatureFromParametersElement:(FKSchemaElement *)parametersElement
{
    FKSchemaElement *maximumTemperatureElement = [parametersElement childWithName:@"temperature"
                                                                 attribute:@"type"
                                                            attributeValue:@"maximum"];
    if (!maximumTemperatureElement) {
        [self failWithError:[self errorWithMessage:@"Could not find maximum temperature element."]];
        return;
    }
    
    FKSchemaElement *minimumTemperatureElement = [parametersElement childWithName:@"temperature"
                                                                        attribute:@"type"
                                                                   attributeValue:@"minimum"];
    if (!minimumTemperatureElement) {
        [self failWithError:[self errorWithMessage:@"Could not find minimum temperature element"]];
        return;
    }
    
    // temperatures
    NSArray *keys = @[@"maximumTemperature", @"minimumTemperature"];
    NSArray *elements = @[maximumTemperatureElement, minimumTemperatureElement];
    
    for (NSInteger elementIndex = 0; elementIndex < elements.count; elementIndex ++) {
        NSString *key = [keys objectAtIndex:elementIndex];
        FKSchemaElement *element = [elements objectAtIndex:elementIndex];
        
        NSInteger forecastIndex = 0;
        for (FKSchemaElement *child in element.children) {
            if ([child.name isEqualToString:@"value"]) {
                FKForecast *forecast = [self forecastAtIndex:forecastIndex];
                NSNumber *value = nil;
                if (child.value.length != 0) {
                    value = @([[child value] integerValue]);
                }
                [forecast setValue:value forKey:key];
                forecastIndex ++;
            }
        }
    }
    
    // units
    NSString *units = [[maximumTemperatureElement attributeWithName:@"units"] value];
    for (FKForecast *forecast in self.forecasts) {
        forecast.temperatureUnits = units;
    }
}

- (void)setProbabilityOfPrecipitationFromParametersElement:(FKSchemaElement *)parametersElement
{
    FKSchemaElement *precipitationElement = [parametersElement childWithName:@"probability-of-precipitation"];
    if (!precipitationElement) {
        [self failWithError:[self errorWithMessage:@"Could not find precipitation element."]];
        return;
    }
    
    // check time format
    FKSchemaAttribute *type = [precipitationElement attributeWithName:@"type"];
    if (![type.value isEqualToString:@"12 hour"]) {
        [self failWithError:[self errorWithMessage:[NSString stringWithFormat:@"Found incorrect precipitation time layout: %@", type.value]]];
        return;
    }
    
    for (NSInteger i = 1; i < precipitationElement.children.count - 1; i += 2) {
        FKForecast *forecast = [self forecastAtIndex:(i - 1) / 2];

        NSString *probabilityOne = [(FKSchemaElement *)[precipitationElement.children objectAtIndex:i] value];
        NSString *probabilityTwo = [(FKSchemaElement *)[precipitationElement.children objectAtIndex:i+1] value];
        NSInteger probability;

        if (probabilityOne.length == 0 && probabilityTwo.length == 0) {
            forecast.probabilityOfPrecipitation = nil;
        } else {
            probability = MAX([probabilityOne integerValue], [probabilityTwo integerValue]);
            forecast.probabilityOfPrecipitation = @(probability);
        }
    }
}

- (void)setWeatherSummaryFromParametersElement:(FKSchemaElement *)parametersElement
{
    FKSchemaElement *weather = [parametersElement childWithName:@"weather"];
    NSInteger forecastIndex = 0;
    for (FKSchemaElement *child in weather.children) {
        if ([child.name isEqualToString:@"weather-conditions"]) {
            FKForecast *forecast = [self forecastAtIndex:forecastIndex];
            NSString *weatherSummary = [[child attributeWithName:@"weather-summary"] value];
            if (weatherSummary.length) {
                forecast.summary = weatherSummary;
            }
            forecastIndex ++;
        }
    }
}

- (void)createForecasts
{
    FKSchemaElement *data = [self.rootElement childWithName:@"data"];
    if (!data) {
        [self failWithError:[self errorWithMessage:[NSString stringWithFormat:@"No data available for this location."]]];
        return;
    }
    
    [self setGeopositionFromDataElement:data];
    [self setTimeLayoutFromDataElement:data];
    
    FKSchemaElement *parameters = [data childWithName:@"parameters"];
    
    [self setTemperatureFromParametersElement:parameters];
    [self setProbabilityOfPrecipitationFromParametersElement:parameters];
    [self setWeatherSummaryFromParametersElement:parameters];
    
    [self reportForecasts];
}

#pragma mark - Public

- (BOOL)parseResponse:(NSData *)responseData
{
    if (self.parser) {
        return NO;
    }
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:responseData];
    self.parser = parser;
    parser.delegate = self;
    [parser parse];
#if !__has_feature(objc_arc)
    [parser release];
#endif
    
    return YES;
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    [self failWithError:parseError];
}

- (void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validationError
{
    [self failWithError:validationError];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
    [self createForecasts];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    if (self.currentElement) {
        self.currentParentElement = self.currentElement;
    }
    FKSchemaElement *newElement = [[FKSchemaElement alloc] init];
    newElement.name = elementName;
    self.currentElement = newElement;
    
    if (self.currentParentElement) {
        newElement.parent = self.currentParentElement;
        [self.currentParentElement.children addObject:newElement];
    }
    
    for (NSString *attributeKey in [attributeDict allKeys]) {
        FKSchemaAttribute *attribute = [[FKSchemaAttribute alloc] init];
        attribute.name = attributeKey;
        attribute.value = [attributeDict objectForKey:attributeKey];
        [newElement.attributes addObject:attribute];
        
#if !__has_feature(objc_arc)
        [attribute release];
#endif
    }
    
    if (!self.rootElement) {
        self.rootElement = newElement;
    }
    
#if !__has_feature(objc_arc)
    [newElement release];
#endif
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if (!self.currentElementValue) {
        self.currentElementValue = [NSMutableString stringWithString:string];
    } else {
        [self.currentElementValue appendString:string];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    NSString *value = nil;
    if (self.currentElementValue) {
        value = [self.currentElementValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        self.currentElementValue = nil;
    }
    if ([elementName isEqualToString:self.currentParentElement.name]) {
        if (value) {
            self.currentParentElement.value = value ;
        }
        
        self.currentParentElement = self.currentParentElement.parent;
    } else if ([elementName isEqualToString:self.currentElement.name]) {
        if (value) {
            self.currentElement.value = value;
        }
        
        self.currentElement = nil;
    }
}

- (NSDate *)dateFromDWMLDate:(NSString *)dateString
{
    if (dateString.length != 25) {
#if DEBUG
        NSLog(@"Error: received invalid time string (%@).", dateString);
#endif
        return nil;
    }
    
    NSString *relevantSubstring = [dateString substringToIndex:19];
    NSString *timeZoneSubstring = [dateString substringFromIndex:19];
    self.dateFormatter.timeZone = [NSTimeZone timeZoneWithName:[@"GMT" stringByAppendingString:timeZoneSubstring]];
        
    NSDate *date = [self.dateFormatter dateFromString:relevantSubstring];
    return date;
}

@end

#pragma mark - Schema Objects

@implementation FKSchemaItem

#if !__has_feature(objc_arc)
- (void)dealloc
{
    [_name release];
    [_value release];
    
    [super dealloc];
}
#endif

@end

@implementation FKSchemaAttribute
@end

@interface FKSchemaElement ()
@property (strong, nonatomic) NSMutableArray *children;
@property (strong, nonatomic) NSMutableSet *attributes;
@end

@implementation FKSchemaElement

#if !__has_feature(objc_arc)
- (void)dealloc
{
    [_children release];
    [_attributes release];
    
    [super dealloc];
}
#endif

- (NSMutableArray *)children
{
    if (!_children) {
        _children = [[NSMutableArray alloc] init];
    }
    return _children;
}

- (FKSchemaElement *)childWithName:(NSString *)elementName
{
    return [self childWithName:elementName attribute:nil attributeValue:nil];
}

- (FKSchemaElement *)childWithName:(NSString *)elementName attribute:(NSString *)attributeName attributeValue:(NSString *)attributeValue
{
    if (!_children) {
        return nil;
    }
    
    BOOL checkAttribute = (attributeName && attributeValue);
    NSInteger childIndex = [self.children indexOfObjectPassingTest:^BOOL(FKSchemaElement *element, NSUInteger idx, BOOL *stop) {
        BOOL found = [[element name] isEqualToString:elementName];
        if (checkAttribute && found) {
            FKSchemaAttribute *attribute = [element attributeWithName:attributeName];
            found = (attribute && [attribute.value isEqualToString:attributeValue]);
        }
        
        if (found) {
            *stop = YES;
        }
        return found;
    }];
    
    if (childIndex == NSNotFound) {
        return nil;
    }
    return [self.children objectAtIndex:childIndex];
}

- (NSInteger)countOfChildren
{
    if (!_children) {
        return 0;
    }
    return [_children count];
}

- (NSMutableSet *)attributes
{
    if (!_attributes) {
        _attributes = [[NSMutableSet alloc] init];
    }
    return _attributes;
}

- (FKSchemaAttribute *)attributeWithName:(NSString *)attributeName
{
    if (!_attributes) {
        return nil;
    }
    
    NSSet *matches = [_attributes objectsPassingTest:^BOOL(FKSchemaAttribute *attribute, BOOL *stop) {
        BOOL found = [[attribute name] isEqualToString:attributeName];
        if (found) {
            *stop = YES;
        }
        return found;
    }];
    
    if (matches.count == 0) {
        return nil;
    }
    
    return [matches anyObject];
}

- (NSInteger)countOfAttributes
{
    if (!_attributes) {
        return 0;
    }
    return [_attributes count];
}

@end