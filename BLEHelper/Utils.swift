//
//  Utils.swift
//  BLEHelper
//
//  Created by HarveyHu on 2/27/16.
//  Copyright © 2016 HarveyHu. All rights reserved.
//  Edit by Giles on 11/22/2016

import Foundation

func prettyLog(_ message: String = "", file:String = #file, function:String = #function, line:Int = #line) {
    
    print("\((file as NSString).lastPathComponent)(\(line)) \(function) \(message)")
}
