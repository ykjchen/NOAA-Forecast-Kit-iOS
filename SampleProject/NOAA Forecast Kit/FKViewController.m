//
//  FKViewController.m
//  NOAA Forecast Kit
//
//  Created by Joseph Chen on 1/6/14.
//  Copyright (c) 2014 Joseph Chen. All rights reserved.
//

#import "FKViewController.h"

#import "FKDataManager.h"
#import "FKForecast.h"
#import "FKLocation.h"

@interface FKViewController () <UIAlertViewDelegate, UITableViewDataSource>

@property (strong, nonatomic) UIToolbar *toolbar;
@property (strong, nonatomic) UITableView *tableview;
@property (strong, nonatomic) NSArray *forecasts;
@property (strong, nonatomic) NSString *forecastsTitle;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;

@end


typedef enum {
    FKViewControllerSubviewInvalid,
    FKViewControllerSubviewZipcodeAlert
} FKViewControllerSubview;

@implementation FKViewController

- (NSDateFormatter *)dateFormatter
{
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    }
    return _dateFormatter;
}

- (UIBarButtonItem *)spaceItem
{
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                         target:nil
                                                         action:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    _toolbar = [[UIToolbar alloc] init];
    [self.view addSubview:_toolbar];
    
    UIBarButtonItem *currentLocationItem = [[UIBarButtonItem alloc] initWithTitle:@"For Current Location"
                                                                              style:UIBarButtonItemStyleBordered
                                                                             target:self
                                                                             action:@selector(tappedForecastForCurrentLocationItem:)];
    UIBarButtonItem *zipcodeItem = [[UIBarButtonItem alloc] initWithTitle:@"For Zipcode"
                                                                    style:UIBarButtonItemStyleBordered
                                                                   target:self
                                                                   action:@selector(tappedForecastForZipcodeItem:)];
    [_toolbar setItems:@[[self spaceItem], currentLocationItem, [self spaceItem], zipcodeItem, [self spaceItem]]];
    
    _tableview = [[UITableView alloc] initWithFrame:CGRectZero
                                              style:UITableViewStyleGrouped];
    _tableview.dataSource = self;
    [self.view addSubview:_tableview];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    CGFloat toolbarHeight = 44.0f;
    self.toolbar.frame = CGRectMake(0.0f, 0.0f, self.view.bounds.size.width, toolbarHeight);
    
    self.tableview.frame = CGRectMake(0.0f, toolbarHeight, self.view.bounds.size.width, self.view.bounds.size.height - toolbarHeight);
}

- (void)tappedForecastForCurrentLocationItem:(UIBarButtonItem *)item
{
    NSError *requestError = nil;
    BOOL requested = [[FKDataManager sharedManager] requestForecastsForCurrentLocationWithCompletion:^(NSArray *forecasts, NSError *error) {
        if (forecasts) {
            self.forecastsTitle = @"Weather for Current Location";
        }
        [self processForecasts:forecasts error:error];
    } error:&requestError];

    if (!requested) {
#if DEBUG
        NSLog(@"Error requesting forecasts: %@", requestError.localizedDescription);
#endif
    }
}

- (void)tappedForecastForZipcodeItem:(UIBarButtonItem *)item
{
    UIAlertView *zipcodeAlert = [[UIAlertView alloc] initWithTitle:@"Request Forecasts"
                                                           message:@"Enter a zipcode:"
                                                          delegate:self
                                                 cancelButtonTitle:@"Cancel"
                                                 otherButtonTitles:@"OK", nil];
    zipcodeAlert.tag = FKViewControllerSubviewZipcodeAlert;
    zipcodeAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [zipcodeAlert show];
}

- (void)requestForecastsForZipcode:(NSString *)zipcode
{
    NSError *requestError = nil;
    BOOL requested = [[FKDataManager sharedManager] requestForecastsForZipcode:zipcode
                                                                    completion:^(NSArray *forecasts, NSError *error) {
                                                                        if (forecasts) {
                                                                            FKLocation *location = [[FKDataManager sharedManager] locationForZipcode:zipcode];
                                                                            if (location) {
                                                                                self.forecastsTitle = [NSString stringWithFormat:@"Weather for %@, %@", location.city, location.state];
                                                                            } else {
                                                                                self.forecastsTitle = [NSString stringWithFormat:@"Weather for %@", zipcode];
                                                                            }
                                                                        }
                                                                        [self processForecasts:forecasts error:error];
                                                                    } error:&requestError];
    if (!requested) {
#if DEBUG
        NSLog(@"Error requesting forecasts: %@", requestError.localizedDescription);
#endif
    }
}

- (void)processForecasts:(NSArray *)forecasts error:(NSError *)error
{
#if DEBUG
    if (!forecasts) {
        NSLog(@"Error encountered during request: %@", error.localizedDescription);
    }
#endif
    
    self.forecasts = forecasts;
    [self.tableview reloadData];
}
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == FKViewControllerSubviewZipcodeAlert) {
        if (buttonIndex == [alertView firstOtherButtonIndex]) {
            NSString *zipcode = [[alertView textFieldAtIndex:0] text];
            [self requestForecastsForZipcode:zipcode];
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.forecasts.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return self.forecastsTitle;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const reuseIdentifier = @"Cell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:reuseIdentifier];
    }

    FKForecast *forecast = [self.forecasts objectAtIndex:indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ — %@", [self.dateFormatter stringFromDate:forecast.startDate], [self.dateFormatter stringFromDate:forecast.endDate]];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Max %@°F | Min %@°F | Prec %@%%", forecast.maximumTemperature, forecast.minimumTemperature, forecast.probabilityOfPrecipitation];
    return cell;
}

@end
