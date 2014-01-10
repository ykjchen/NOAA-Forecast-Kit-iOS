NOAAForecastKit
===============

Objective-C Wrapper for NOAA's Weather Forecast REST API

Use this project as a starting point for querying weather data from [National Digital Forecast Database (NDFD) REST Web Service](http://graphical.weather.gov/xml/rest.php). FKDataManager is a singleton that queries  
* maximum/minimum temperature,
* probability of precipitation, 
* and a weather summary  

by current location or zipcode. The code can be extended if other data is required.

The project uses zipcode data from [CivicSpace Labs, Inc.](http://www.boutell.com/zipcodes/), which is released under a [Creative Commons Attribution-ShareAlike license](http://creativecommons.org/licenses/by-sa/2.0/).


###Add to your project
1. Link `CoreData.framework` and `CoreLocation.framework`.
2. Drag the `NOAAForecastKit` directory into your project.

###Requesting 7-day forecasts

Use the following instance methods of the singleton `[FKDataManager sharedManager]` to request forecast data.

Request a 7-day forecast at the device's current location:

    - (BOOL)requestForecastsForCurrentLocationWithCompletion:(void (^)(NSArray *forecasts, NSError *error))completionHandler
                                                       error:(NSError *__autoreleasing *)preRequestError;
                                                       
Request a 7-day forecast at a given zipcode:          

    - (BOOL)requestForecastsForZipcode:(NSString *)zipcode
                            completion:(void (^)(NSArray *forecasts, NSError *error))completionHandler
                                 error:(NSError *__autoreleasing *)preRequestError;
                                 
If the request cannot be sent, the methods return `NO` with error details in `preRequestError`. If the request is sent but fails at any point, `forecasts` will be `nil` when `completionHandler` is called, and error details will be provided in `error`.

If the request is successful, a `NSArray` of 7 `FKForecast` objects is returned. Each `FKForecast` object has the following properties:

    @property (nonatomic, retain) NSNumber * latitude;                    // a float (degrees)
    @property (nonatomic, retain) NSNumber * longitude;                   // a float (degrees)
    @property (nonatomic, retain) NSDate * startDate;                     // start of forecast period
    @property (nonatomic, retain) NSDate * fetchDate;                     // date data was fetched
    @property (nonatomic, retain) NSDate * endDate;                       // end of forecast period
    @property (nonatomic, retain) NSString * summary;                     // e.g. "Sunny"
    @property (nonatomic, retain) NSNumber * minimumTemperature;          // an integer
    @property (nonatomic, retain) NSNumber * maximumTemperature;          // an integer
    @property (nonatomic, retain) NSString * temperatureUnits;            // Fahrenheit or Celsius
    @property (nonatomic, retain) NSNumber * probabilityOfPrecipitation;  // an integer with units of percent
    
###Get details of a location from a zipcode

`[FKDataManager sharedManager]` can return details of a zipcode's location, e.g. for populating your UI.

    - (FKLocation *)locationForZipcode:(NSString *)zipcode;
    
This method returns nil if the zipcode passed in is not within the database shipped in the bundle (`Zipcodes.sqlite`). Otherwise it returns an `FKLocation` object which has the following properties:

    @property (nonatomic, retain) NSNumber * zipcode;
    @property (nonatomic, retain) NSString * state;         // two-letter abbreviation
    @property (nonatomic, retain) NSNumber * longitude;
    @property (nonatomic, retain) NSNumber * latitude;
    @property (nonatomic, retain) NSString * city;          // city name

###Customization

To request other data from NDFD, modify the parameters sent to the service in `FKForecastRequester`, which handles the request to the service and receipt of the response.

    - (NSURLRequest *)urlRequestForLatitude:(float)latitude longitude:(float)longitude;
    
The response is sent to a `FKResponseParser`, which will also need to be modified. Parsing of the XML response yields a tree of `FKSchemaElement` objects. Each `FKSchemaElement` object represents an element (node) in the XML, and has the following properties:

    @property (strong, nonatomic) NSString *name;
    @property (strong, nonatomic) NSString *value;
    @property (weak, nonatomic) FKSchemaElement *parent;        // This element's parent in the tree (FKSchemaElement)
    @property (nonatomic, readonly) NSMutableArray *children;   // This element's children (FKSchemaElements)
    @property (nonatomic, readonly) NSMutableSet *attributes;   // This element's attributes (FKSchemaAttributes)
    
`FKSchemaAttribute` instances have:

    @property (strong, nonatomic) NSString *name;
    @property (strong, nonatomic) NSString *value;
    
You should customize the creation of `FKForecast`s in the `-createForecasts` method and call `-reportForecasts` when finished.

The structure of the XML responses is specified at [http://graphical.weather.gov/xml/mdl/XML/Design/MDL_XML_Design.htm](http://graphical.weather.gov/xml/mdl/XML/Design/MDL_XML_Design.htm).

Sample responses can be viewed through the following URLs:
[http://graphical.weather.gov/xml/sample_products/browser_interface/ndfdXML.htm](http://graphical.weather.gov/xml/sample_products/browser_interface/ndfdXML.htm) [http://graphical.weather.gov/xml/sample_products/browser_interface/ndfdBrowserByDay.htm](http://graphical.weather.gov/xml/sample_products/browser_interface/ndfdBrowserByDay.htm)
