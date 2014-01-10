//
//  FKStore.m
//  NOAA Forecast Kit
//
//  Created by Joseph Chen on 1/7/14.
//  Copyright (c) 2014 Joseph Chen. All rights reserved.
//

#import "FKStore.h"

#import <CoreData/CoreData.h>

#import "FKForecast.h"
#import "FKLocation.h"

#pragma mark - Helpers

NSString *FKPathForFileInDirectory(NSString *fileName, NSSearchPathDirectory nsspd)
{
    NSArray *directories = NSSearchPathForDirectoriesInDomains(nsspd, NSUserDomainMask, YES);
    NSString *directory = [directories objectAtIndex:0];
    
    if (fileName == nil) {
        return directory;
    } else {
        return [directory stringByAppendingPathComponent:fileName];
    }
}

NSString *FKPathInDataDirectory(NSString *fileName)
{
    NSString *libraryDirectory = FKPathForFileInDirectory(nil, NSLibraryDirectory);
    NSString *dataDirectory = [libraryDirectory stringByAppendingPathComponent:@"FKData"];
    BOOL isDir;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dataDirectory isDirectory:&isDir]) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:dataDirectory
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error]) {
#if DEBUG
            NSLog(@"Error: could not create data directory path (%@)", error.localizedDescription);
#endif
        }
    } else if (!isDir) {
#if DEBUG
        NSLog(@"Error: file at data directory path is not a directory.");
#endif
        return nil;
    }
    
    if (fileName == nil) {
        return dataDirectory;
    } else {
        return [dataDirectory stringByAppendingPathComponent:fileName];
    }
}

#pragma mark - FKStore

@interface FKStore ()

@property (strong, nonatomic) NSManagedObjectModel *model;
@property (strong, nonatomic) NSManagedObjectContext *context;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end

@implementation FKStore

#if !__has_feature(objc_arc)
- (void)dealloc
{
    [_context release];
    [_persistentStoreCoordinator release];
    [_model release];
    
    [super dealloc];
}
#endif

- (id)init
{
    if ((self = [super init])) {
        [self createCoreDataStack];
    }
    return self;
}

#pragma mark - Stack Management

- (void)createCoreDataStack
{
    // create
    if (!_model) {
        NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"FKDataModel" ofType:@"mom" inDirectory:@"FKDataModel.momd"];
        NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
        _model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    }
    
    if (!_persistentStoreCoordinator) {
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_model];
        
        // immutable store
        NSString *immutableStorePath = [[NSBundle mainBundle] pathForResource:@"Zipcodes"
                                                                       ofType:@"sqlite"];
        //NSString *immutableStorePath = FKPathInDataDirectory(@"Zipcodes.sqlite");
        if (immutableStorePath) {
            NSError *immutableStoreError = nil;
            if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                           configuration:@"Immutable"
                                                                     URL:[NSURL fileURLWithPath:immutableStorePath]
                                                                 options:nil
                                                                   error:&immutableStoreError]) {
#if DEBUG
                NSLog(@"Error: could not open immutable store (%@).", immutableStoreError.localizedDescription);
#endif
            }            
        }
        
        // mutable store
        NSString *mutableStorePath = FKPathInDataDirectory(@"MutableStore.sqlite");
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                                 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
        
        NSError *mutableStoreError = nil;
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                       configuration:@"Mutable"
                                                                 URL:[NSURL fileURLWithPath:mutableStorePath]
                                                             options:options
                                                               error:&mutableStoreError]) {
#if DEBUG
            NSLog(@"Error: could not open mutable store (%@).", mutableStoreError.localizedDescription);
#endif
        }
    }
    
    // Create the managed object context
    if (!_context) {
        _context = [[NSManagedObjectContext alloc] init];
        [_context setPersistentStoreCoordinator:_persistentStoreCoordinator];
        [_context setUndoManager:nil];
    }
}

- (BOOL)saveContext
{
    NSError *error = nil;
    BOOL successful = [[self context] save:&error];
#if DEBUG
    if (!successful) {
        NSLog(@"Error: could not save context (%@)", [error localizedDescription]);
        NSArray *detailedErrors = [[error userInfo] objectForKey:NSDetailedErrorsKey];
        if (detailedErrors != nil && [detailedErrors count] > 0) {
            for (NSError *detailedError in detailedErrors) {
                NSLog(@"  DetailedError: %@", [detailedError userInfo]);
            }
        } else {
            NSLog(@"  %@", [error userInfo]);
        }
    }
#endif
    
    return successful;
}

- (NSManagedObjectModel *)model
{
    if (!_model) {
        [self createCoreDataStack];
    }
    return _model;
}

- (NSManagedObjectContext *)context
{
    if (!_context) {
        [self createCoreDataStack];
    }
    return _context;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (!_persistentStoreCoordinator) {
        [self createCoreDataStack];
    }
    return _persistentStoreCoordinator;
}

#pragma mark - Data Management

- (NSArray *)fetchObjectsForKey:(NSString *)key
                      predicate:(id)predicate
                 sortDescriptor:(NSString *)sortDescriptor
                  sortAscending:(BOOL)sortAscending
                     fetchLimit:(NSUInteger)fetchLimit
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:key];
    
    if (predicate != nil) {
        if ([predicate isKindOfClass:[NSString class]]) {
            NSPredicate *pred = [NSPredicate predicateWithFormat:predicate];
            [request setPredicate:pred];
        } else if ([predicate isKindOfClass:[NSPredicate class]]) {
            [request setPredicate:predicate];
        }
    }
    
    if (sortDescriptor != nil) {
        NSSortDescriptor *sd = [NSSortDescriptor
                                sortDescriptorWithKey:sortDescriptor
                                ascending:sortAscending];
        [request setSortDescriptors:[NSArray arrayWithObject:sd]];
    }
    
    [request setFetchLimit:fetchLimit];
    
    NSError *error;
    NSArray *result = [[self context] executeFetchRequest:request error:&error];
    
#if DEBUG
    if (!result) {
        [NSException raise:@"Fetch failed"
                    format:@"Reason: %@", [error localizedDescription]];
    }
#endif
    
    return result;
}

- (FKLocation *)locationForZipcode:(NSString *)zipcode
{
    NSArray *hits = [self fetchObjectsForKey:@"FKLocation"
                                   predicate:[NSString stringWithFormat:@"zipcode == %i", [zipcode intValue]]
                              sortDescriptor:nil
                               sortAscending:NO
                                  fetchLimit:1];
    if (hits.count == 0) {
        return nil;
    }

    return [hits objectAtIndex:0];
}

- (FKForecast *)forecastForLatitude:(float)latitude longitude:(float)longitude date:(NSDate *)date
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"latitude == %f && longitude == %f && startDate == %@", latitude, longitude, date];
    NSArray *matches = [self fetchObjectsForKey:@"FKForecast"
                                      predicate:predicate
                                 sortDescriptor:nil
                                  sortAscending:NO
                                     fetchLimit:1];
    FKForecast *forecast;
    if (matches.count == 0) {
        forecast = [NSEntityDescription insertNewObjectForEntityForName:@"FKForecast"
                                                 inManagedObjectContext:self.context];
        forecast.latitude = @(latitude);
        forecast.longitude = @(longitude);
        forecast.startDate = date;
    } else {
        forecast = [matches objectAtIndex:0];
    }
    
    return forecast;
}

@end
