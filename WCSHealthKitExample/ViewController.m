//
//  ViewController.m
//  WCSHealthKit
//
//  Created by Aaron C. Wright on 8/14/15.
//  Copyright © 2015 Wrights Creative Services, L.L.C. All rights reserved.
//
//  aaron@wrightscs.com
//  http://www.wrightscs.com, http://www.wrightscsapps.com
//

#import "ViewController.h"
#import "WCSHealthKit.h"

@interface ViewController () <UITextFieldDelegate, WCSHealthKitDelegate>
@property (nonatomic, strong) IBOutlet UITextField * tfHeight, * tfWeight, * tfSteps;
@property (nonatomic, strong) IBOutlet UILabel * labelWeight, * labelHeight, * labelBirthday, * labelEnergy, * labelSteps;
@property (nonatomic, strong) IBOutlet UISegmentedControl * heightControl, * weightControl, * energyControl;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [_heightControl setSelectedSegmentIndex:[[NSUserDefaults standardUserDefaults] integerForKey:@"kUnitMeasureHeight"]];
    [_weightControl setSelectedSegmentIndex:[[NSUserDefaults standardUserDefaults] integerForKey:@"kUnitMeasureWeight"]];
    [_energyControl setSelectedSegmentIndex:[[NSUserDefaults standardUserDefaults] integerForKey:@"kUnitMeasureEnergy"]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[WCSHealthKit sharedKit] authorize:^(BOOL success) {
        if ( ! success )
            NSLog(@"Unable to authorize WCSHealthKit!");
        [self updateLabels];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - HKEngineDelegate

- (void)didReceiveError:(WCSHKErrorType)error
{
    NSString * _errorString = @"Could not get sample.";
    switch ( error ) {
        case WCSHKErrorTypeUnknown:
            _errorString = @"Unable to determine the authorization status, please check iOS settings.";
            break;
        case WCSHKErrorTypeAuthorization:
            _errorString = @"This app faild to authorize with HealthKit!";
            break;
        default:
            break;
    }
    UIAlertController * _alert = [UIAlertController alertControllerWithTitle:@"HealthKit Error" message:_errorString preferredStyle:UIAlertControllerStyleAlert];
    [_alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [_alert dismissViewControllerAnimated:YES completion:NULL];
    }]];
    [[WCSHealthKit rootController] presentViewController:_alert animated:YES completion:NULL];
}

#pragma mark - Private Methods

- (void)updateLabels
{
    _labelBirthday.text = [[WCSHealthKit sharedKit] birthday];
    
    NSString * _wUnit = @"kg";
    switch ( _weightControl.selectedSegmentIndex ) {
        case 0: { // gram
            _wUnit = @"g";
            break;
        }
        case 1: { // pound
            _wUnit = @"lbs";
            break;
        }
    }
    [[WCSHealthKit sharedKit] weight:^(double weight) {
        _labelWeight.text = [NSString stringWithFormat:@"%.f %@", weight, _wUnit];
    }];
    
    
    NSString * _hUnit = @"cm";
    switch ( _heightControl.selectedSegmentIndex ) {
        case 0: { // cenitimeter
            _hUnit = @"cm";
            break;
        }
        case 1: { // inches
            _hUnit = @"in";
            break;
        }
    }
    [[WCSHealthKit sharedKit] height:^(double height) {
        _labelHeight.text = [NSString stringWithFormat:@"%.f %@", height, _hUnit];
    }];
    
    [[WCSHealthKit sharedKit] steps:^(double steps) {
        _labelSteps.text = [NSString stringWithFormat:@"%.f steps today", steps];
    }];
    
    [[WCSHealthKit sharedKit] energy:^(NSString * energy) {
        _labelEnergy.text = [NSString stringWithFormat:@"%@", energy];
    }];
}

#pragma mark IBActions

- (IBAction)control_energy:(UISegmentedControl*)control {
    [self dismissKeyboard:^{
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:control.selectedSegmentIndex] forKey:@"kUnitMeasureEnergy"];
        if ( [[NSUserDefaults standardUserDefaults] synchronize] ) {
            [self updateLabels];
        }
    }];
}

#pragma mark steps

- (IBAction)steps:(id)sender {
    [self dismissKeyboard:^{
        [[WCSHealthKit sharedKit] recordSteps:[_tfSteps.text doubleValue] completion:^(BOOL recorded, NSError *error) {
            if ( ! error ) {
                [[WCSHealthKit sharedKit] steps:^(double steps) {
                    _labelSteps.text = [NSString stringWithFormat:@"%.f steps today", steps];
                }];
            }
            else
                _labelSteps.text = @"Could not record steps!";
        }];
    }];
}

#pragma mark height

- (IBAction)control_height:(UISegmentedControl*)control {
    [self dismissKeyboard:^{
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:control.selectedSegmentIndex] forKey:@"kUnitMeasureHeight"];
        if ( [[NSUserDefaults standardUserDefaults] synchronize] ) {
            switch ( control.selectedSegmentIndex ) {
                case 0: { // gram
                    _tfHeight.placeholder = @"Height in centimenters";
                    break;
                }
                case 1: { // pound
                    _tfHeight.placeholder = @"Height in inches";
                    break;
                }
            }
        }
        [self updateLabels];
    }];
}
- (IBAction)height:(id)sender {
    [self dismissKeyboard:^{
        [[WCSHealthKit sharedKit] recordHeight:[_tfHeight.text doubleValue] completion:^(BOOL recorded, NSError *error) {
            if ( recorded ) {
                [[WCSHealthKit sharedKit] height:^(double height) {
                    [self updateLabels];
                }];
            }
            else
                _labelHeight.text = @"Could not record height!";
        }];
    }];
}

#pragma mark weight

- (IBAction)control_weight:(UISegmentedControl*)control {
    [self dismissKeyboard:^{
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:control.selectedSegmentIndex] forKey:@"kUnitMeasureWeight"];
        if ( [[NSUserDefaults standardUserDefaults] synchronize] ) {
            switch ( control.selectedSegmentIndex ) {
                case 0: { // gram
                    _tfWeight.placeholder = @"Weight in grams";
                    break;
                }
                case 1: { // pound
                    _tfWeight.placeholder = @"Weight in pounds";
                    break;
                }
                case 2: { // kilogram
                    _tfWeight.placeholder = @"Weight in kilograms";
                    break;
                }
            }
        }
        [self updateLabels];
    }];
}
- (IBAction)weight:(id)sender {
    [self dismissKeyboard:^{
        [[WCSHealthKit sharedKit] recordWeight:[_tfWeight.text doubleValue] completion:^(BOOL recorded, NSError *error) {
            if ( recorded ) {
                [[WCSHealthKit sharedKit] weight:^(double weight) {
                    [self updateLabels];
                }];
            }
            else
                _labelWeight.text = @"Could not record weight!";
        }];
    }];
}


#pragma mark - UITextField Delegates

- (void)dismissKeyboard:(void (^)(void))completion
{
    float dismiss = .25f;
    if ( _tfHeight.isFirstResponder )
        [_tfHeight resignFirstResponder];
    else if ( _tfWeight.isFirstResponder )
        [_tfWeight resignFirstResponder];
    else if ( _tfSteps.isFirstResponder )
        [_tfSteps resignFirstResponder];
    else
        dismiss = 0.f;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dismiss * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        completion();
    });
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}


@end
