//
//  BLECentralManager.swift
//  BLEHelper
//
//  Created by HarveyHu on 2/26/16.
//  Copyright © 2016 HarveyHu. All rights reserved.
//  Edit by Giles on 11/22/2016

import Foundation
import CoreBluetooth


class BLECentralManager: NSObject {
    //MARK: - Blocks Declaration
    typealias DiscoverPeripheralCompletion = (_ peripheral: CBPeripheral, _ advertisementData: [String : AnyObject], _ RSSI: NSNumber) -> (Void)
    typealias ConnectPeripheralCompletion = (_ peripheral: CBPeripheral, _ error: NSError?) -> (Void)
    typealias DisconnectPeripheralCompletion = (_ peripheral: CBPeripheral, _ error: NSError?) -> (Void)
    typealias DiscoverServicesHandler = (_ peripheral: CBPeripheral, _ error: NSError?) -> (Void)
    typealias DiscoverCharacteristicsForServiceHandler = (_ peripheral: CBPeripheral, _ service: CBService, _ error: NSError?) -> (Void)
    typealias FetchCharacteristicCompletion = (_ characteristic: CBCharacteristic) -> (Void)
    typealias ReceiveDataHandler = (_ data: Data?, _ peripheral: CBPeripheral, _ characteristic: CBCharacteristic) -> (Void)
    typealias ReadResponse = (_ success: Bool) -> (Void)
    typealias SetNotifyResponse = (_ success: Bool) -> (Void)
    typealias WriteResponse = (_ success: Bool) -> (Void)
    typealias ReadRSSI = (_ peripheral: CBPeripheral, _ RSSI: NSNumber, _ error: NSError?) -> (Void)

    var didDiscoverPeripheralCompletion: DiscoverPeripheralCompletion?
    var didConnectPeripheralCompletion: ConnectPeripheralCompletion?
    var didDisconnectPeripheralCompletion: DisconnectPeripheralCompletion?
    var didDiscoverServicesHandler: DiscoverServicesHandler?
    var didDiscoverCharacteristicsForServiceHandler: DiscoverCharacteristicsForServiceHandler?
    var didFetchCharacteristicCompletion: FetchCharacteristicCompletion?
    var didReceiveDataHandler: ReceiveDataHandler?
    var didReadResponse: ReadResponse?
    var didSetNotifyResponse: SetNotifyResponse?
    var didWriteResponse: WriteResponse?
    var didReadRSSI: ReadRSSI?
    
    //MARK: - Basic Settings
    fileprivate var centralManager: CBCentralManager?
    // [deviceUUID : [characteristicUUID: CBCharacteristic]]
    fileprivate var deviceCharacteristicMap = [String : [String : CBCharacteristic]]()
    
    required init(queue: DispatchQueue) {
        super.init()
        centralManager = CBCentralManager.init(delegate: self, queue: queue)
    }
    
    deinit {
        centralManager = nil
        releaseBlocks()
    }
    
    //MARK: - Private Functions
    fileprivate func closeAllNotifications(_ peripheral: CBPeripheral) {
        if let services = peripheral.services {
            for service in services {
                if let characteristics = service.characteristics {
                    for characteristic in characteristics {
                        if characteristic.isNotifying {
                            peripheral.setNotifyValue(false, for: characteristic)
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func releaseBlocks() {
        didDiscoverPeripheralCompletion = nil
        didConnectPeripheralCompletion = nil
        didDisconnectPeripheralCompletion = nil
        didDiscoverServicesHandler = nil
        didDiscoverCharacteristicsForServiceHandler = nil
        didFetchCharacteristicCompletion = nil
        didReceiveDataHandler = nil
        didReadResponse = nil
        didSetNotifyResponse = nil
        didWriteResponse = nil
        didReadRSSI = nil
    }
    
    //MARK: - BLE Discovering
    /*
    *  @Discoverying
    */
    func scanWithServiceUUID(_ serviceUUID: String?,  discoverPeripheralCompletion: @escaping DiscoverPeripheralCompletion) {
        prettyLog()
        self.didDiscoverPeripheralCompletion = discoverPeripheralCompletion
        
        //callack on didDiscoverPeripheral: delegate
        if let uuidString = serviceUUID {
            let uuids = [CBUUID.init(string: uuidString)]
            centralManager?.scanForPeripherals(withServices: uuids, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        } else {
            centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }
    
    func stopScan() {
        centralManager?.stopScan()
    }
    
    //MARK: - BLE Connecting
    /*
    *  @Connecting
    */
    func connect(_ peripheral: CBPeripheral, completion: ConnectPeripheralCompletion?) {
        self.didConnectPeripheralCompletion = completion
        centralManager?.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(value: true as Bool)])
    }
    
    func retrievePeripheralByDeviceUUID(_ deviceUUIDs: [UUID], completion: ConnectPeripheralCompletion?) {
        self.didConnectPeripheralCompletion = completion
        
        if let peripherals = centralManager?.retrievePeripherals(withIdentifiers: deviceUUIDs) {
            for peripheral in peripherals
            {
                prettyLog("connect with deviceUUID:\(peripheral.identifier)")
                centralManager?.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(value: true as Bool)])
            }
        }
    }
    
    func disconnect(_ peripheral: CBPeripheral) {
        closeAllNotifications(peripheral)
        self.deviceCharacteristicMap.removeValue(forKey: peripheral.identifier.uuidString)
        centralManager?.cancelPeripheralConnection(peripheral)
    }
    
    
    //MARK - BLE Exploring
    /*!
    *  @Exploring
    */
    func fetchCharacteristic(_ peripheral:CBPeripheral, serviceUUID: String, characteristicUUID: String, completion: @escaping FetchCharacteristicCompletion) {
        prettyLog("deviceUUID: \(peripheral.identifier.uuidString)")
        
        // if it's found before, use it.
        if let characteristicMap = deviceCharacteristicMap[peripheral.identifier.uuidString], let characteristic = characteristicMap[characteristicUUID] {
            completion(characteristic)
            return
        }
        
        //set callback
        self.didFetchCharacteristicCompletion = completion
        self.didDiscoverServicesHandler = {(peripheral: CBPeripheral, error: NSError?) -> (Void) in
            if error != nil {
                prettyLog("error:" + error!.description)
                return
            }
            prettyLog()
            
            if let services = peripheral.services {
                for service in services {
                    prettyLog("[debug] serviceUUID:\(service.uuid.uuidString) input UUID:\(serviceUUID)")
                    if service.uuid.uuidString == serviceUUID {
                        peripheral.discoverCharacteristics([CBUUID.init(string: characteristicUUID)], for: service)
                    } else {
                        break
                    }
                }
            }
        }
        self.didDiscoverCharacteristicsForServiceHandler = {[weak self] (peripheral: CBPeripheral, service: CBService, error: NSError?) in
            if error != nil {
                prettyLog("error:" + error!.description)
                return
            }
            prettyLog()
            
            if let characteristics = service.characteristics {
                for characteristic in characteristics {
                    self?.deviceCharacteristicMap[peripheral.identifier.uuidString] = [characteristic.uuid.uuidString: characteristic]
                    if characteristic.uuid.uuidString == characteristicUUID {
                        self?.didFetchCharacteristicCompletion?(characteristic)
                    }
                }
            }
        }
        
        //start from getting services
        peripheral.discoverServices([CBUUID.init(string: serviceUUID)])
    }
    
    //MARK - BLE Interacting
    //reading
    func readValueFromCharacteristic(_ peripheral:CBPeripheral, characteristic: CBCharacteristic, completion:ReadResponse?) {
        self.didReadResponse = completion
        peripheral.readValue(for: characteristic)
    }
    
    //writing
    func writeValueWithData(_ peripheral:CBPeripheral, characteristic: CBCharacteristic, data: Data, withResponse: Bool, response: WriteResponse?) {
        self.didWriteResponse = response
        peripheral.writeValue(data, for: characteristic, type: withResponse ? .withResponse : .withoutResponse)
    }
    
    //notify
    func setNotificationState(_ peripheral:CBPeripheral, turnOn onOrOff: Bool, characteristic: CBCharacteristic, response: SetNotifyResponse?) {
        let p = characteristic.isNotifying
        let q = onOrOff
        if (p || q) && !(p && q) {
            self.didSetNotifyResponse = response
            peripheral.setNotifyValue(onOrOff, for: characteristic)
        }
    }
    
    //readRSSI
    func readRSSI(_ peripheral: CBPeripheral, completion: @escaping ReadRSSI) {
        self.didReadRSSI = completion
        peripheral.readRSSI()
    }
}

//MARK: - Extension for CBCentralManagerDelegate
extension BLECentralManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        prettyLog()
        
        if #available(iOS 10.0, *) {
            //self.managerState = central.state
            switch central.state {
            case CBManagerState.unauthorized:
               print("Central manager state: Unsopported")
                break
            case CBManagerState.poweredOff:
                   print("Central manager state: Powered off")
                break
            case CBManagerState.resetting:
                 print("Central manager state: Resseting")
                break
            case CBManagerState.poweredOn:
                 print("Central manager state: Powered on")
                break
                
            default:
                break
            }
        }else{
            
            switch central.state {
            case .unknown:
                print("Central manager state: Unknown")
                break
                
            case .resetting:
                print("Central manager state: Resseting")
                break
                
            case .unsupported:
                print("Central manager state: Unsopported")
                break
                
            case .unauthorized:
                print("Central manager state: Unauthorized")
                break
                
            case .poweredOff:
                print("Central manager state: Powered off")
                break
                
            case .poweredOn:
                print("Central manager state: Powered on")
                break
            }
        
        }
        
        
       
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        prettyLog("peripheral:\(peripheral)\nadvertisementData\(advertisementData)\n\(RSSI)")
        didDiscoverPeripheralCompletion?(peripheral, advertisementData as [String : AnyObject], RSSI)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        prettyLog()
        peripheral.delegate = self
        didConnectPeripheralCompletion?(peripheral, nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        didConnectPeripheralCompletion?(peripheral, error as NSError?)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        didDisconnectPeripheralCompletion?(peripheral, error as NSError?)
    }
}

//MARK: - Extension for CBPeripheralDelegate
extension BLECentralManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        didReadRSSI?(peripheral, RSSI, error as NSError?)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        didDiscoverServicesHandler?(peripheral, error as NSError?)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        didDiscoverCharacteristicsForServiceHandler?(peripheral, service, error as NSError?)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            prettyLog("error:" + error!.localizedDescription)
            self.didReadResponse?(false)
            return
        }
        prettyLog()
        self.didReadResponse?(true)
        self.didReadResponse = nil
        self.didReceiveDataHandler?(characteristic.value, peripheral, characteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            prettyLog("error:" +  error!.localizedDescription)
            self.didWriteResponse?(false)
            return
        }
        prettyLog()
        self.didWriteResponse?(true)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            prettyLog("error:" +  error!.localizedDescription)
            self.didSetNotifyResponse?(false)
            return
        }
        prettyLog()
        self.didSetNotifyResponse?(true)
    }
}
