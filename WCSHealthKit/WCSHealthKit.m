//
//  WCSHealthKit.m
//  WCSHealthKit
//
//  Created by Aaron C. Wright on 8/14/15.
//  Copyright © 2015 Wrights Creative Services, L.L.C. All rights reserved.
//
//  aaron@wrightscs.com
//  http://www.wrightscs.com, http://www.wrightscsapps.com
//

#import "WCSHealthKit.h"

@interface WCSHealthKit ()
@property (nonatomic, strong) HKHealthStore *healthStore;
- (void)isAuthorizedForType:(HKObjectType*)type onSuccess:(void (^)())success onError:(void (^)())error;
@end

@implementation WCSHealthKit

+ (WCSHealthKit *)sharedKit
{
    static WCSHealthKit *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!instance) {
            instance = [[self alloc] init];
        }
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        if ([HKHealthStore isHealthDataAvailable]) {
             _healthStore = [[HKHealthStore alloc] init];
        }
    }
    return self;
}

- (void)authorize:(void (^)(BOOL success))completion {
    if ([HKHealthStore isHealthDataAvailable]) {
        _healthStore = [[HKHealthStore alloc] init];
        [_healthStore requestAuthorizationToShareTypes:[self dataTypes:WCSHKDataTypeWrite] readTypes:[self dataTypes:WCSHKDataTypeRead] completion:^(BOOL success, NSError *error) {
            if ( ! success ) {
                NSLog(@"Unable to authorize with HealthKit. Error - %@", error);
                if ( [_delegate respondsToSelector:@selector(didReceiveError:)] )
                     [_delegate didReceiveError:WCSHKErrorTypeAuthorization];
            }
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completion(success);
            });
        }];
    }
}

- (BOOL)isAuthorized
{
    BOOL _authorized = NO;
    for ( HKObjectType * objectType in [self dataTypes:WCSHKDataTypeRead] ) {
        if ( [_healthStore authorizationStatusForType:objectType] == HKAuthorizationStatusSharingAuthorized ) {
            _authorized = YES;
            break;
        }
    }
    return _authorized;
}

- (void)isAuthorizedForType:(HKObjectType*)type onSuccess:(void (^)())success onError:(void (^)())error
{
    BOOL _success = NO;
    if ( [HKHealthStore isHealthDataAvailable] )
    {
        switch ( [_healthStore authorizationStatusForType:type] ) {
            case HKAuthorizationStatusNotDetermined: {
                if ( [_delegate respondsToSelector:@selector(didReceiveError:)] )
                     [_delegate didReceiveError:WCSHKErrorTypeUnknown];
                break;
            }
            case HKAuthorizationStatusSharingDenied:{
                if ( [_delegate respondsToSelector:@selector(didReceiveError:)] )
                     [_delegate didReceiveError:WCSHKErrorTypeAuthorization];
                break;
            }
            case HKAuthorizationStatusSharingAuthorized: {
                _success = YES;
                break;
            }
        }
    }
    else
        _success = NO;
    
    if ( _success ) success(); else error();
}

#pragma mark - HealthKit Permissions

// Returns the types of data to read/write from HealthKit.
- (NSSet *)dataTypes:(WCSHKDataType)dataType {
    switch ( dataType ) {
        case WCSHKDataTypeRead: {
            return [NSSet setWithObjects:
                    [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount],
                    [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight],
                    [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass],
                    [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBasalEnergyBurned], // Resting Energy
                    [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned], // Active Energy
                    [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryEnergyConsumed], // Dietary Calories
                    [HKCharacteristicType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierDateOfBirth],
                    [HKCharacteristicType characteristicTypeForIdentifier: HKCharacteristicTypeIdentifierBiologicalSex],
                    nil
                    ];
            break;
        }
        case WCSHKDataTypeWrite: {
            return [NSSet setWithObjects:
                    [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount],
                    [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight],
                    [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass],
                    nil
                    ];
            break;
        }
    }
}

#pragma mark HealthKit Fetching

- (void)fetchMostRecentDataOfQuantityType:(HKQuantityType *)quantityType withCompletion:(void (^)(HKQuantity *mostRecentQuantity, NSError *error))completion
{
    [self isAuthorizedForType:quantityType onSuccess:^{
        
        NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate ascending:NO];
        HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:quantityType predicate:nil limit:HKObjectQueryNoLimit sortDescriptors:@[timeSortDescriptor] resultsHandler:^(HKSampleQuery *query, NSArray *results, NSError *error) {
            if (completion && error) {
                completion(nil, error);
                return;
            }
            // If quantity isn't in the database, return nil in the completion block.
            HKQuantitySample *quantitySample = results.firstObject;
            HKQuantity *quantity = quantitySample.quantity;
            
            if (completion) completion(quantity, error);
        }];
        
        [_healthStore executeQuery:query];
        
    }
    onError:^{
        ;
    }];
}
- (void)fetchTotalJoulesConsumedWithCompletionHandler:(void (^)(double, NSError *))completionHandler
{
    HKQuantityType *sampleType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBasalEnergyBurned];
    [self isAuthorizedForType:sampleType onSuccess:^{
        
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDate *now = [NSDate date];
        NSDateComponents *components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:now];
        NSDate *startDate = [calendar dateFromComponents:components];
        NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
        
        NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
        
        HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:sampleType quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
            if (completionHandler && error) {
                completionHandler(0.0f, error);
                return;
            }
            
            double totalCalories = [result.sumQuantity doubleValueForUnit:[HKUnit jouleUnit]];
            if (completionHandler) {
                completionHandler(totalCalories, error);
            }
        }];
        
        [self.healthStore executeQuery:query];
        
    }
    onError:^{
        ;
    }];
}

#pragma mark Energy Formatting

- (NSEnergyFormatter *)energyFormatter {
    static NSEnergyFormatter *energyFormatter;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        energyFormatter = [[NSEnergyFormatter alloc] init];
        energyFormatter.unitStyle = NSFormattingUnitStyleLong;
        energyFormatter.forFoodEnergyUse = YES;
        energyFormatter.numberFormatter.maximumFractionDigits = 2;
    });
    
    return energyFormatter;
}


#pragma mark - Dates

- (NSDate*)midnight {
    NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    [cal setTimeZone:[NSTimeZone systemTimeZone]];
    NSDateComponents * comp = [cal components:( NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute) fromDate:[NSDate date]];
    [comp setMinute:0];
    [comp setHour:0];
    NSDate *startOfToday = [cal dateFromComponents:comp];
    return startOfToday;
}

#pragma mark - Units

- (HKUnit*)unit_height {
    switch ( [[[NSUserDefaults standardUserDefaults] objectForKey:@"kUnitMeasureHeight"] integerValue] ) {
        case 1: return [HKUnit unitFromString:@"in"]; break;
    }
    return [HKUnit unitFromString:@"cm"];
}

- (HKUnit*)unit_weight {
    switch ( [[[NSUserDefaults standardUserDefaults] objectForKey:@"kUnitMeasureWeight"] integerValue] ) {
        case 0: return [HKUnit gramUnit]; break;
        case 1: return [HKUnit poundUnit]; break;
    }
    return [HKUnit unitFromString:@"kg"];
}


#pragma mark - Getters

- (NSString*)birthday
{
    NSError * error = nil;
    NSDate * _birthday = [_healthStore dateOfBirthWithError:&error];
    
    NSDate * _date = ( error ? [NSDate date] : _birthday );
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"MM-dd-yyyy"];
    return [NSString stringWithFormat:@"Date of Birth: %@", [dateFormat stringFromDate:_date]];
}

- (void)steps:(void (^)(double steps))completion
{
    HKQuantityType *quantityType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    [self isAuthorizedForType:quantityType onSuccess:^{
        
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *interval = [[NSDateComponents alloc] init];
        interval.day = 1;
        
        __block double numSteps = 0;
        NSDateComponents *anchorComponents = [calendar components:NSCalendarUnitDay|NSCalendarUnitMonth|NSCalendarUnitYear fromDate:[NSDate date]];
        anchorComponents.hour = 0;
        NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
        
        // Create the query
        HKStatisticsCollectionQuery *query =
        [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType quantitySamplePredicate:nil
                                                          options:HKStatisticsOptionCumulativeSum
                                                       anchorDate:anchorDate
                                               intervalComponents:interval];
        // Set the results handler
        query.initialResultsHandler = ^(HKStatisticsCollectionQuery *query, HKStatisticsCollection *results, NSError *error) {
            if ( ! error )
            {
                [results enumerateStatisticsFromDate:[self midnight] toDate:[NSDate date] withBlock:^(HKStatistics *result, BOOL *stop) {
                    HKQuantity *quantity = result.sumQuantity;
                    if ( quantity ) {
                        double value = [quantity doubleValueForUnit:[HKUnit countUnit]];
                        numSteps = numSteps + value;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(numSteps);
                    });
                }];
            }
            else
                NSLog(@"*** An error occurred while calculating the statistics: %@ ***",error.localizedDescription);
        };
        
        [_healthStore executeQuery:query];
        
    }
    onError:^{
        
        NSLog(@"Error - Could not read steps.");
    }];
}

- (void)height:(void (^)(double height))completion {
    HKQuantityType *heightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    [self isAuthorizedForType:heightType onSuccess:^{
        
        [self fetchMostRecentDataOfQuantityType:heightType withCompletion:^(HKQuantity *mostRecentQuantity, NSError *error) {
            if ( ! error )
            {
                // Determine the weight in the required unit.
                double usersHeight = 0.0;
                if (mostRecentQuantity) {
                    usersHeight = [mostRecentQuantity doubleValueForUnit:[self unit_height]];
                    // Update the user interface.
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(usersHeight);
                    });
                }
            }
            else
                completion(0);
        }];
        
    }
    onError:^{
        
        NSLog(@"Error - Could not read height.");
    }];
}

- (void)weight:(void (^)(double weight))completion {
    HKQuantityType *weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    [self isAuthorizedForType:weightType onSuccess:^{

        [self fetchMostRecentDataOfQuantityType:weightType withCompletion:^(HKQuantity *mostRecentQuantity, NSError *error) {
            if ( ! error )
            {
                // Determine the weight in the required unit.
                double usersWeight = 0.0;
                if (mostRecentQuantity) {
                    usersWeight = [mostRecentQuantity doubleValueForUnit:[self unit_weight]];
                    // Update the user interface on main thread.
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(usersWeight);
                    });
                }
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(0);
                });
            }
        }];
        
    }
    onError:^{
        
        NSLog(@"Error - Could not read weight.");
    }];
}

- (void)energy:(void (^)(NSString * energy))completion
{
    HKQuantityType * energyType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryEnergyConsumed];
    switch ( [[[NSUserDefaults standardUserDefaults] objectForKey:@"kUnitMeasureEnergy"] integerValue] ) {
        case 0: {
            energyType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBasalEnergyBurned];
            break;
        }
        case 1: {
            energyType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
            break;
        }
    }
    
    // Does not need to be authorized; will return "0 Calories" instead.
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDateComponents *components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:[NSDate date]];
    
    NSDate *startDate = [calendar dateFromComponents:components];
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:energyType quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
        double totalCalories = [result.sumQuantity doubleValueForUnit:[HKUnit jouleUnit]];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([[self energyFormatter] stringFromJoules:totalCalories]);
        });
    }];
    
    [_healthStore executeQuery:query];
}


#pragma mark Setters

- (void)recordSteps:(double)increment completion:(void (^)(BOOL recorded, NSError * error))completion
{
    HKQuantityType * stepsType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    [self isAuthorizedForType:stepsType onSuccess:^{
        
        HKQuantity *stepQuantity = [HKQuantity quantityWithUnit:[HKUnit countUnit] doubleValue:increment];
        HKQuantitySample *stepsSample = [HKQuantitySample quantitySampleWithType:stepsType quantity:stepQuantity startDate:[NSDate date] endDate:[NSDate date]];
        [_healthStore saveObject:stepsSample withCompletion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(success, error);
            });
        }];
        
    }
    onError:^{
        ;
    }];
}

- (void)recordHeight:(double)height completion:(void (^)(BOOL recorded, NSError * error))completion
{
    HKQuantityType *heightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    [self isAuthorizedForType:heightType onSuccess:^{
        
        HKQuantity *heightQuantity = [HKQuantity quantityWithUnit:[self unit_height] doubleValue:height];
        HKQuantitySample *heightSample = [HKQuantitySample quantitySampleWithType:heightType quantity:heightQuantity startDate:[NSDate date] endDate:[NSDate date]];
        [_healthStore saveObject:heightSample withCompletion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(success, error);
            });
        }];
        
    }
    onError:^{
        
        NSLog(@"Error - Could not record height.");
    }];
}

- (void)recordWeight:(double)weight completion:(void (^)(BOOL recorded, NSError * error))completion
{
    HKQuantityType *weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    [self isAuthorizedForType:weightType onSuccess:^{
        
        HKQuantity *weightQuantity = [HKQuantity quantityWithUnit:[self unit_weight] doubleValue:weight];
        HKQuantitySample *weightSample = [HKQuantitySample quantitySampleWithType:weightType quantity:weightQuantity startDate:[NSDate date] endDate:[NSDate date]];
        [_healthStore saveObject:weightSample withCompletion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(success, error);
            });
        }];
        
    }
    onError:^{
        
        NSLog(@"Error - Could not record weight.");
    }];
}

#pragma mark - Utilities

+ (id)rootController {
    return [[[UIApplication sharedApplication] keyWindow] rootViewController];
}

@end
