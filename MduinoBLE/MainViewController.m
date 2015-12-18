//
//  MainViewController.m
//  MduinoBLE
//
//  Created by chifu on 2015/12/13.
//  Copyright © 2015年 chifu. All rights reserved.
//

#import "MainViewController.h"

#define SERVICE_UUID           @"FFE0"
#define CHARACTERISTIC_UUID    @"FFE1"

@interface MainViewController ()

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [_centralManager stopScan];
    NSLog(@"Scanning stopped");
    self.lblLampStatus.text = @"Scanning stopped";
    [super viewWillDisappear:animated];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    // You should test all scenarios
    if (central.state != CBCentralManagerStatePoweredOn) {
        return;
    }
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        // Scan for devices
        [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
        NSLog(@"Scanning started");
        self.lblLampStatus.text = @"Scanning started";
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    self.lblLampStatus.text = [NSString stringWithFormat:@"Discovered %@ at %@", peripheral.name, RSSI];
    
    if (_discoveredPeripheral != peripheral) {
        // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
        _discoveredPeripheral = peripheral;
        
        // And connect
        NSLog(@"Connecting to peripheral %@", peripheral);
        self.lblLampStatus.text = [NSString stringWithFormat:@"Connecting to peripheral %@", peripheral];
        [_centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Failed to connect");
    self.lblLampStatus.text = @"Failed to connect";
    [self cleanup];
}


- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected");
    self.lblLampStatus.text = @"Connected";
    
    [_centralManager stopScan];
    NSLog(@"Scanning stopped");
    self.lblLampStatus.text = @"Scanning stopped";
    
    peripheral.delegate = self;
    [peripheral discoverServices:@[[CBUUID UUIDWithString:SERVICE_UUID]]];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        [self cleanup];
        return;
    }
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:CHARACTERISTIC_UUID]] forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self cleanup];
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID]]) {
            NSLog(@"Reading value for characteristic %@", CHARACTERISTIC_UUID);
            self.lblLampStatus.text = [NSString stringWithFormat:@"Reading value for characteristic %@", CHARACTERISTIC_UUID];
            [peripheral readValueForCharacteristic:characteristic];
            //[peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error");
        self.lblLampStatus.text = @"Error";
        return;
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID]]) {
        return;
    }
    
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
        self.lblLampStatus.text = [NSString stringWithFormat:@"Notification began on %@", characteristic];
        
    } else {
        // Notification has stopped
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error writing characteristic value: %@", [error localizedDescription]);
        self.lblLampStatus.text = [NSString stringWithFormat:@"Error writing characteristic value: %@", [error localizedDescription]];
    }
    
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    _discoveredPeripheral = nil;
    
    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
}

- (void)cleanup {
    
    // See if we are subscribed to a characteristic on the peripheral
    if (_discoveredPeripheral.services != nil) {
        for (CBService *service in _discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            [_discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
    }
    
    [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
}

-(void)writeCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID data:(NSData *)data {
    // Sends data to BLE peripheral to process HID and send EHIF command to PC
    for ( CBService *service in peripheral.services ) {
        
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            
            for ( CBCharacteristic *characteristic in service.characteristics ) {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]]) {
                    // EVERYTHING IS FOUND, WRITE characteristic!
                    [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
                    
                    // make sure the received characteristic value and then update status image
                    [peripheral readValueForCharacteristic:characteristic];
                    
                }
            }
        }
    }
}


- (IBAction)btnPressed:(id)sender {
    char dataByte;
    switch ([sender tag]) {
        case 0:
            dataByte = 'f';
            break;
        case 1:
            dataByte = 'l';
            break;
        case 2:
            dataByte = 'r';
            break;
        case 3:
            dataByte = 'b';
            break;
        default:
            dataByte = 's';
            break;
    }
    [self writeCharacteristic:_discoveredPeripheral sUUID:SERVICE_UUID cUUID:CHARACTERISTIC_UUID data:[NSData dataWithBytes:&dataByte length:1]];
}

- (IBAction)btnUp:(id)sender {
    char dataByte = 's';
    [self writeCharacteristic:_discoveredPeripheral sUUID:SERVICE_UUID cUUID:CHARACTERISTIC_UUID data:[NSData dataWithBytes:&dataByte length:1]];
}

@end
