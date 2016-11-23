//
//  BLECentralHelper.swift
//  BLEHelper
//
//  Created by HarveyHu on 2/27/16.
//  Copyright © 2016 HarveyHu. All rights reserved.
//  Edit by Giles on 11/22/2016

import Foundation
import CoreBluetooth

public protocol BLECentralHelperDelegate {
    func bleDidDisconnectFromPeripheral(_ peripheral: CBPeripheral)
    func bleCentralDidReceiveData(_ data: Data?, peripheral: CBPeripheral,characteristic: CBCharacteristic)
}

open class BLECentralHelper {
    open var delegate: BLECentralHelperDelegate?
    let centralManager: BLECentralManager
    var peripheralScanList = [CBPeripheral] ()
    open internal(set) var connectedPeripherals = [String: CBPeripheral] ()
    var timer: Timer?
    var scanCompletion: ((_ peripheralList: [CBPeripheral])->(Void))?
    
    public init() {
        // Set centralManager
        let bleCentralQueue: DispatchQueue = DispatchQueue(label: "forBLECentralManagerOnly", attributes: [])
        centralManager = BLECentralManager(queue: bleCentralQueue)
        centralManager.didReceiveDataHandler = {[weak self] (data: Data?, peripheral: CBPeripheral ,characteristic: CBCharacteristic) -> (Void) in
            DispatchQueue.main.async(execute: { () -> Void in
                self?.delegate?.bleCentralDidReceiveData(data ,peripheral: peripheral, characteristic: characteristic)
            })
        }
        centralManager.didDisconnectPeripheralCompletion = {[weak self] (peripheral, error) -> (Void) in
            DispatchQueue.main.async(execute: { () -> Void in
                self?.delegate?.bleDidDisconnectFromPeripheral(peripheral)
            })
        }
    }
    
    deinit {
        self.delegate = nil
        self.timer?.invalidate()
        self.timer = nil
        self.scanCompletion = nil
    }
    
    dynamic func scanTimeout() {
        prettyLog("Scan Timeout")
        self.centralManager.stopScan()
        scanCompletion?(self.peripheralScanList)
    }
    
    //MARK - BLE Scan
    open func scan(_ seconds: Double, serviceUUID: String?, handler:((_ devices: [CBPeripheral]) -> (Void))?) {
        prettyLog()
        self.timer?.invalidate()
        centralManager.stopScan()
        
        scanCompletion = handler
        
        self.timer = Timer.scheduledTimer(timeInterval: seconds, target: self, selector: #selector(BLECentralHelper.scanTimeout), userInfo: nil, repeats: false)
        
        centralManager.scanWithServiceUUID(serviceUUID) {[weak self] (peripheral, advertisementData, RSSI) -> (Void) in
            if self?.peripheralScanList.filter({$0.identifier.uuidString == peripheral.identifier.uuidString}).count == 0 || self?.peripheralScanList.count == 0 {
                self?.peripheralScanList.append(peripheral)
            }
        }
    }
    
    //MARK - BLE Connect
    open func connect(_ peripheral: CBPeripheral, completion: ((_ peripheral: CBPeripheral, _ error: NSError?) -> (Void))?) {
        prettyLog("connect with peripheral: \(peripheral.identifier.uuidString)")
        self.timer?.invalidate()
        centralManager.stopScan()
        
        centralManager.connect(peripheral, completion: {[weak self] (peripheral: CBPeripheral, error: NSError?) in
            
            if let strongSelf = self {
                strongSelf.connectedPeripherals.updateValue(peripheral, forKey: peripheral.identifier.uuidString)
            }
            completion?(peripheral, error)
        })
    }
    
    open func retrieve(deviceUUIDs deviceUUIDStrings: [String], completion: ((_ peripheral: CBPeripheral, _ error: NSError?) -> (Void))?) {
        prettyLog()
        self.timer?.invalidate()
        centralManager.stopScan()
        
        let deviceUUIDs = deviceUUIDStrings.map { (uuidString) -> UUID in
            return UUID.init(uuidString: uuidString)!
        }
        
        //must scan to get peripheral instance
        self.scan(1.0, serviceUUID: nil) {[weak self] (devices) -> (Void) in
            self?.centralManager.retrievePeripheralByDeviceUUID(deviceUUIDs, completion: {[weak self] (peripheral: CBPeripheral, error: NSError?) in
                if let strongSelf = self {
                    strongSelf.connectedPeripherals.updateValue(peripheral, forKey: peripheral.identifier.uuidString)
                }
                completion?(peripheral, error)
            })
        }
    }
    
    open func disconnect(_ deviceUUID: String?) {
        prettyLog("deviceUUID: \(deviceUUID)")
        if let uuid = deviceUUID {
            if let p = self.connectedPeripherals[uuid] {
                centralManager.disconnect(p)
                self.connectedPeripherals.removeValue(forKey: uuid)
            }
        } else {
            for (_, p) in self.connectedPeripherals {
                centralManager.disconnect(p)
            }
            self.connectedPeripherals.removeAll()
        }
        self.peripheralScanList.removeAll()
    }
    
    open func isConnected(_ deviceUUID: String) -> Bool {
        if self.connectedPeripherals[deviceUUID]?.state == CBPeripheralState.connected {
            return true
        }
        return false
    }
    
    //MARK: - BLE Operation
    //read
    open func readValue(_ deviceUUID: String, serviceUUID: String, characteristicUUID: String, response: @escaping (_ success: Bool)-> (Void)) {
        guard let peripheral = self.connectedPeripherals[deviceUUID] else {
            prettyLog("error: peripheral = nil")
            return
        }
        prettyLog("deviceUUID: \(deviceUUID)")
        
        centralManager.fetchCharacteristic(peripheral, serviceUUID: serviceUUID, characteristicUUID: characteristicUUID) {[weak self] (characteristic) -> (Void) in
            self?.centralManager.readValueFromCharacteristic(peripheral, characteristic: characteristic, completion: response)
        }
    }
    
    //notify
    open func enableNotification(_ enable: Bool, deviceUUID: String, serviceUUID: String, characteristicUUID: String, response:@escaping (_ success: Bool) -> (Void)) {
        guard let peripheral = self.connectedPeripherals[deviceUUID] else {
            prettyLog("error: peripheral = nil")
            return
        }
        prettyLog("deviceUUID: \(deviceUUID)")
        
        centralManager.fetchCharacteristic(peripheral, serviceUUID: serviceUUID, characteristicUUID: characteristicUUID) {[weak self] (characteristic) -> (Void) in
            self?.centralManager.setNotificationState(peripheral, turnOn: enable, characteristic: characteristic, response: response)
        }
    }
    
    //write
    open func writeValue(_ data: Data, deviceUUID: String, serviceUUID: String, characteristicUUID: String, withResponse: Bool, response:@escaping (_ success: Bool) -> (Void)) {
        guard let peripheral = self.connectedPeripherals[deviceUUID] else {
            prettyLog("error: peripheral = nil")
            return
        }
        prettyLog("deviceUUID: \(deviceUUID)")
        
        centralManager.fetchCharacteristic(peripheral, serviceUUID: serviceUUID, characteristicUUID: characteristicUUID) {[weak self] (characteristic) -> (Void) in
            self?.centralManager.writeValueWithData(peripheral, characteristic: characteristic, data: data, withResponse: withResponse, response: response)
        }
    }
}


