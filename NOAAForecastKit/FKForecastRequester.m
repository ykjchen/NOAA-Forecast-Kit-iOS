//
//  FKForecastRequester.m
//  NOAA Forecast Kit
//
//  Created by Joseph Chen on 1/7/14.
//  Copyright (c) 2014 Joseph Chen. All rights reserved.
//

#import "FKForecastRequester.h"

// server
#define NDFD_REQUEST_URL @"http://www.weather.gov/forecasts/xml/sample_products/browser_interface/ndfdBrowserClientByDay.php"

@interface FKForecastRequester () <NSURLConnectionDataDelegate>

@end

@implementation FKForecastRequester

- (NSURLRequest *)urlRequestForLatitude:(float)latitude longitude:(float)longitude
{
    NSString *path = [NSString stringWithFormat:@"%@?lat=%f&lon=%f&format=24+hourly", NDFD_REQUEST_URL, latitude, longitude];
    NSURL *url = [NSURL URLWithString:path];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url
                                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                              timeoutInterval:60.0];
#if !__has_feature(objc_arc)
    return [request autorelease];
#else
    return request;
#endif
}

- (void)failWithError:(NSError *)error
{
    if (self.delegate &&
        [self.delegate conformsToProtocol:@protocol(FKForecastRequesterDelegate)]
        && [self.delegate respondsToSelector:@selector(forecastRequester:didFailWithError:)]) {
        [self.delegate forecastRequester:self didFailWithError:error];
    }
}

#pragma mark - Public

- (BOOL)requestForecastsForLatitude:(float)latitude
                          longitude:(float)longitude
                              error:(NSError *__autoreleasing *)preRequestError
{
    NSString *errorMessage = nil;
    if (errorMessage) {
        NSDictionary *errorDetails = [NSDictionary dictionaryWithObject:errorMessage
                                                                 forKey:NSLocalizedDescriptionKey];
        *preRequestError = [NSError errorWithDomain:@"FKForecastRequesterDomain"
                                               code:0
                                           userInfo:errorDetails];
        return NO;
    }
    
    FKURLConnection *urlConnection = [[FKURLConnection alloc] initWithRequest:[self urlRequestForLatitude:latitude longitude:longitude]
                                                                     delegate:self];
#if !__has_feature(objc_arc)
    [urlConnection autorelease];
#endif
    
    [urlConnection start];
    return YES;
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self failWithError:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [(FKURLConnection *)connection setData:[NSMutableData data]];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [[(FKURLConnection *)connection data] appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSData *responseData = [(FKURLConnection *)connection data];
    
    if (self.delegate &&
        [self.delegate conformsToProtocol:@protocol(FKForecastRequesterDelegate)] &&
        [self.delegate respondsToSelector:@selector(forecastRequester:receivedResponse:)]) {
        [self.delegate forecastRequester:self receivedResponse:responseData];
    }
}

@end

@implementation FKURLConnection
#if !__has_feature(objc_arc)
- (void)dealloc
{
    [_data release];
    
    [super dealloc];
}
#endif
@end

