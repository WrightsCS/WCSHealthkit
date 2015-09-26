//
//  HKEngine.h
//  WCSHealthKit
//
//  Created by Aaron C. Wright on 8/14/15.
//  Copyright © 2015 Wrights Creative Services, L.L.C. All rights reserved.
//
//  aaron@wrightscs.com
//  http://www.wrightscs.com, http://www.wrightscsapps.com
//

@import UIKit;
@import Foundation;
@import HealthKit;


/** WCSHealthKit Data Type Read/Write */
typedef NS_ENUM(NSInteger, WCSHKDataType) {
    /** HealthKit Read Data */
    WCSHKDataTypeRead = 0,
    /** HealthKit Write Data */
    WCSHKDataTypeWrite
};
/** WCSHealthKit Error Type */
typedef NS_ENUM(NSInteger, WCSHKErrorType) {
    /** WCSHealthKit Error type Unknown */
    WCSHKErrorTypeUnknown = -1,
    /** WCSHealthKit Error type Authorization */
    WCSHKErrorTypeAuthorization = 0,
    /** WCSHealthKit Error type Sample error */
    WCSHKErrorTypeSampleError
};


@class WCSHealthKit;

@protocol WCSHealthKitDelegate <NSObject>
@optional
/** didReceiveError is called when attempting to access HealthKit and a sample type is not authorized. */
- (void)didReceiveError:(WCSHKErrorType)error;
@end


@interface WCSHealthKit : NSObject

@property (nonatomic, weak) id<WCSHealthKitDelegate> delegate;

@property (readonly) BOOL isAuthorized;

+ (WCSHealthKit *)sharedKit;
+ (id)rootController;

/** HealthKit authorization */
- (void)authorize:(void (^)(BOOL success))completion;

/**  Date of birth (MM-dd-yyyy format) */
- (NSString*)birthday;

/** Retrieve stored height, weight */
- (void)height:(void (^)(double height))completion;
- (void)weight:(void (^)(double weight))completion;

/** Steps since midnight */
- (void)steps:(void (^)(double steps))completion;

/** Calories (resting, active, dietary) */
- (void)energy:(void (^)(NSString * energy))completion;

/** Record steps (incremental), height, weight */
- (void)recordSteps:(double)increment completion:(void (^)(BOOL recorded, NSError * error))completion;
- (void)recordHeight:(double)height completion:(void (^)(BOOL recorded, NSError * error))completion;
- (void)recordWeight:(double)weight completion:(void (^)(BOOL recorded, NSError * error))completion;

@end
