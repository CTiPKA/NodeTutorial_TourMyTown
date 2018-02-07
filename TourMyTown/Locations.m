//
//  Locations.m
//  TourMyTown
//
//  Created by Michael Katz on 8/15/13.
//  Copyright (c) 2013 mikekatz. All rights reserved.
//

#import "Locations.h"
#import "Location.h"

static NSString* const kBaseURL = @"http://localhost:3000/";
static NSString* const kLocations = @"locations";
static NSString* const kFiles = @"files";


@interface Locations ()
@property (nonatomic, strong) NSMutableArray* objects;
@end

@implementation Locations

- (id)init
{
    self = [super init];
    if (self) {
        _objects = [NSMutableArray array];
    }
    return self;
}

- (NSArray*) filteredLocations
{
    return [self objects];
}

- (void) addLocation:(Location*)location {
    [self.objects addObject:location];
}

- (void)loadImage:(Location*)location {
    NSLog(@"Loading image for location: %@", location._id);
    NSURL* url = [NSURL URLWithString:[[kBaseURL stringByAppendingPathComponent:kFiles] stringByAppendingPathComponent:location.imageId]];
    
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDownloadTask* task = [session downloadTaskWithURL:url completionHandler:^(NSURL *fileLocation, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSData* imageData = [NSData dataWithContentsOfURL:fileLocation];
            UIImage* image = [UIImage imageWithData:imageData];
            if (!image) {
                NSLog(@"unable to build image");
            }
            location.image = image;
            if (self.delegate) {
                [self.delegate modelUpdated];
            }
        }
    }];
    
    [task resume];
}

- (void)parseAndAddLocations:(NSArray*)locations toArray:(NSMutableArray*)destinationArray {
    for (NSDictionary* item in locations) {
        Location* location = [[Location alloc] initWithDictionary:item];
        [destinationArray addObject:location];
        
        if (location.imageId) {
            [self loadImage:location];
        }
    }
    
    if (self.delegate) {
        [self.delegate modelUpdated];
    }
}

- (void)import {
    NSURL* url = [NSURL URLWithString:[kBaseURL stringByAppendingPathComponent:kLocations]];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask* dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error == nil) {
            NSArray* responseArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            [self parseAndAddLocations:responseArray toArray:self.objects];
            NSLog(@"Found locations - %lu", (unsigned long)[self.objects count]);
        }
    }];
    
    [dataTask resume];
}

- (void) runQuery:(NSString *)queryString
{
 
}

- (void) queryRegion:(MKCoordinateRegion)region
{
    
}

- (void) persist:(Location*)location {
     //input safety check
    if (!location || location.name == nil || location.name.length == 0) {
        return;
    }
    
    NSLog(@"Requesting add new location to DB: %@", location);
    
    //if there is an image, save it first
    if (location.image != nil && location.imageId == nil) {
        [self saveNewLocationImageFirst:location];
        return;
    }
    
    NSString* locations = [kBaseURL stringByAppendingPathComponent:kLocations];
    
    BOOL isExistingLocation = location._id != nil;
    NSURL* url = isExistingLocation ? [NSURL URLWithString:[locations stringByAppendingPathComponent:location._id]] :
    [NSURL URLWithString:locations];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = isExistingLocation ? @"PUT" : @"POST";
    
    NSData* data = [NSJSONSerialization dataWithJSONObject:[location toDictionary] options:0 error:NULL];
    request.HTTPBody = data;
    
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask* dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSLog(@"New location successfully added to backend.");
            NSArray* responseArray = @[[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]];
            [self parseAndAddLocations:responseArray toArray:self.objects];
        }
    }];
    [dataTask resume];
}

- (void) saveNewLocationImageFirst:(Location*)location {
    NSURL* url = [NSURL URLWithString:[kBaseURL stringByAppendingPathComponent:kFiles]];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request addValue:@"image/png" forHTTPHeaderField:@"Content-Type"];
    
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
    
    NSData* bytes = UIImagePNGRepresentation(location.image);
    NSURLSessionUploadTask* task = [session uploadTaskWithRequest:request fromData:bytes completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        if (error == nil && [(NSHTTPURLResponse*)response statusCode] < 300) {
            NSDictionary* responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            location.imageId = responseDict[@"_id"];
            [self persist:location];
        }
    }];
    [task resume];
}

@end
