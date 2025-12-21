//
//  Xvtr.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 6/24/17.
//

import Foundation

@MainActor
@Observable
public final class Xvtr {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: UInt32) {
    self.id = id
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  /* ----- from the FlexApi source -----
   xvtr create
   xvtr remove " + _index
   
   xvtr set " + _index + " name=" + _name
   xvtr set " + _index + " if_freq=" + StringHelper.DoubleToString(_ifFreq, "f6")
   xvtr set " + _index + " lo_error=" + StringHelper.DoubleToString(_loError, "f6")
   xvtr set " + _index + " max_power=" + StringHelper.DoubleToString(_maxPower, "f2")
   xvtr set " + _index + " order=" + _order
   xvtr set " + _index + " rf_freq=" + StringHelper.DoubleToString(_rfFreq, "f6")
   xvtr set " + _index + " rx_gain=" + StringHelper.DoubleToString(_rxGain, "f2")
   xvtr set " + _index + " rx_only=" + Convert.ToByte(_rxOnly)
   */
  public static func add() -> String {
    "xvtr create"
  }
  public static func remove(id: UInt32) -> String {
    "xvtr remove \(id.hex)"
  }
  public static func set(id: UInt32, property: Property, value: String) -> String {
    "xvtr set \(id.hex) \(property.rawValue)=\(value)"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = UInt32(properties[0].key, radix: 10) {
      let index = apiModel.xvtrs.firstIndex(where: { $0.id == id })
      // is it in use?
      if inUse {
        let xvtr: Xvtr
        if let index = index {
          // exists, retrieve
          xvtr = apiModel.xvtrs[index]
        } else {
          // new, add
          xvtr = Xvtr(id)
          apiModel.xvtrs.append(xvtr)
        }
        // parse
        xvtr.parse(Array(properties.dropFirst(1)))
        
      } else {
        // remove
        if let index = index {
          apiModel.xvtrs.remove(at: index)
          apiLog(.debug, "Xvtr: REMOVED Id <\(id)>")
        } else {
          apiLog(.debug, "Xvtr: attempt to remove a non-existing entry")
        }
      }
    }
  }

//  // get the id
//    if let id = UInt32(properties[0].key, radix: 10) {
//      let index = apiModel.xvtrs.firstIndex(where: { $0.id == id })
//      // is it in use?
//      if inUse {
//        // YES, add it if not already present
//        if index == nil {
//          apiModel.xvtrs.append(Xvtr(id))
//          apiModel.xvtrs.last!.parse(Array(properties.dropFirst(1)) )
//        } else {
//          // parse the properties
//          apiModel.xvtrs[index!].parse(Array(properties.dropFirst(1)) )
//        }
//        
//      } else {
//        // NO, remove it
//        apiModel.xvtrs.remove(at: index!)
//        apiLog(.debug, "Xvtr: REMOVED <\(id.hex)>")
//      }
//    }
//  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse Xvtr key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Xvtr.Property(rawValue: property.key) else {
        // log it and ignore the Key
        apiLog(.propertyWarning, "Xvtr: Id <\(self.id.hex)> unknown property <\(property.key) = \(property.value)>", property.key)
        continue
      }
      self.apply(property: token, value: property.value)
    }
    // is it initialized?
    if _initialized == false {
      // NO, it is now
      _initialized = true
      apiLog(.debug, "Xvtr: ADDED Id <\(self.id.hex)> name <\(self.name)>") 
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Methods
  
  /// Apply a single property value
  /// - Parameters:
  ///   - property: Property enum value
  ///   - value: String to apply
  private func apply(property: Xvtr.Property, value: String) {
    switch property {
      
    case .name:         name = String(value.prefix(4))
    case .ifFrequency:  ifFrequency = value.mhzToHz
    case .isValid:      isValid = value.bValue
    case .loError:      loError = value.iValue
    case .maxPower:     maxPower = value.iValue
    case .order:        order = value.iValue
    case .preferred:    preferred = value.bValue
    case .rfFrequency:  rfFrequency = value.mhzToHz
    case .rxGain:       rxGain = value.iValue
    case .rxOnly:       rxOnly = value.bValue
    case .twoMeterInt:  twoMeterInt = value.iValue
      
    case .create:       break  // ignored here
    case .remove:       break  // ignored here
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  public let id: UInt32
  
  public private(set) var isValid = false
  public private(set) var preferred = false
  public private(set) var twoMeterInt = 0
  public private(set) var ifFrequency: Hz = 0
  public private(set) var loError = 0
  public private(set) var name = ""
  public private(set) var maxPower = 0
  public private(set) var order = 0
  public private(set) var rfFrequency: Hz = 0
  public private(set) var rxGain = 0
  public private(set) var rxOnly = false
  
  public enum Property: String {
    case create
    case ifFrequency    = "if_freq"
    case isValid        = "is_valid"
    case loError        = "lo_error"
    case maxPower       = "max_power"
    case name
    case order
    case preferred
    case remove
    case rfFrequency    = "rf_freq"
    case rxGain         = "rx_gain"
    case rxOnly         = "rx_only"
    case twoMeterInt    = "two_meter_int"
  }

  private var _initialized = false
}
