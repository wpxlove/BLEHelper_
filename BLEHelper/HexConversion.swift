//
//  HexConversion.swift
//  BBBtest
//
//  Created by Mike on 2016/11/25.
//  Copyright © 2016年 Giles. All rights reserved.
//
/*
let hexString = "68656c6c 6f2c2077 6f726c64"
print(String(hexadecimalString: hexString))
Or,

let originalString = "hello, world"
print(originalString.hexadecimalString())
 */

import Foundation
extension String {
    
    /// Create `Data` from hexadecimal string representation
    ///
    /// This takes a hexadecimal representation and creates a `Data` object. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.
    
    func hexadecimal() -> Data? {
        var data = Data(capacity: characters.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, options: [], range: NSMakeRange(0, characters.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else {
            return nil
        }
        
        return data
    }
}

extension String {
    
    /// Create `String` representation of `Data` created from hexadecimal string representation
    ///
    /// This takes a hexadecimal representation and creates a String object from that. Note, if the string has any spaces, those are removed. Also if the string started with a `<` or ended with a `>`, those are removed, too.
    ///
    /// For example,
    ///
    ///     String(hexadecimal: "<666f6f>")
    ///
    /// is
    ///
    ///     Optional("foo")
    ///
    /// - returns: `String` represented by this hexadecimal string.
    
    init?(hexadecimal string: String) {
        guard let data = string.hexadecimal() else {
            return nil
        }
        
        self.init(data: data, encoding: .utf8)
    }
    
    /// Create hexadecimal string representation of `String` object.
    ///
    /// For example,
    ///
    ///     "foo".hexadecimalString()
    ///
    /// is
    ///
    ///     Optional("666f6f")
    ///
    /// - parameter encoding: The `NSStringCoding` that indicates how the string should be converted to `NSData` before performing the hexadecimal conversion.
    ///
    /// - returns: `String` representation of this String object.
    
    func hexadecimalString() -> String? {
        return data(using: .utf8)?
            .hexadecimal()
    }
    
    func  removeSpaceAndNewline() -> String{
        var temp:String = self.replacingOccurrences(of:" ", with: "")
        temp =  temp.replacingOccurrences(of:"\n", with: "")
        temp = temp.replacingOccurrences(of:"\r", with: "")
        temp  = temp.replacingOccurrences(of:"<", with: "")
        temp = temp.replacingOccurrences(of:">", with: "")
        temp = temp.replacingOccurrences(of: "bytes", with: "")
        
        return temp
    }
    
}

extension Data {
    
    /// Create hexadecimal string representation of `Data` object.
    ///
    /// - returns: `String` representation of this `Data` object.
    
    func hexadecimal() -> String {
        return map { String(format: "%02x", $0) }
            .joined(separator: "")
    }
    
    func byteReciveData(){
        var values = [UInt8](repeating:0, count:self.count)
        return  self.copyBytes(to: &values, count:self.count)
    }
}
