//
//  MainViewController.h
//  MduinoBLE
//
//  Created by chifu on 2015/12/13.
//  Copyright © 2015年 chifu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface MainViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (weak, nonatomic) IBOutlet UILabel *lblLampStatus;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;


@end
