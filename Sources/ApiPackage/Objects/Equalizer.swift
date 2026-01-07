//
//  Equalizer.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

@MainActor
@Observable
public final class Equalizer: Identifiable {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization

  public init(_ id: String) {
    self.id = id
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray, _ inUse: Bool) {
    
    // get the id
    let id = properties[0].key
    if id == "tx" || id == "rx" { return } // legacy equalizer ids, ignore
    let index = apiModel.equalizers.firstIndex(where: { $0.id == id })
    
    // is it in use?
    if inUse {
      let equalizer: Equalizer
      if let index {
        // exists, retrieve
        equalizer = apiModel.equalizers[index]
      } else {
        // new, add
        equalizer = Equalizer(id)
        apiModel.equalizers.append(equalizer)
      }
      // parse
      equalizer.parse(Array(properties.dropFirst(1)) )
      
    } else {
      // remove
      if let index {
        apiModel.equalizers.remove(at: index)
        apiLog(.debug, "Equalizer: REMOVED Id <\(id)>")
      } else {
        apiLog(.debug, "Equalizer: attempt to remove a non-existing entry")
      }
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        apiLog(.propertyWarning, "Equalizer: Id <\(id)> unknown property <\(property.key) = \(property.value)>", property.key) 
        continue
      }
      self.apply(property: token, value: property.value)
    }
    // is it initialized?
    if _initialized == false {
      // NO, it is now
      _initialized = true
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Methods
  
  /// Apply a single property value
  /// - Parameters:
  ///   - property: Property enum value
  ///   - value: String to apply
  private func apply(property: Equalizer.Property, value: String) {
    switch property {
      
    case .eqEnabled:  eqEnabled = value.bValue
    case .hz63:       hz63 = value.iValue
    case .hz125:      hz125 = value.iValue
    case .hz250:      hz250 = value.iValue
    case .hz500:      hz500 = value.iValue
    case .hz1000:     hz1000 = value.iValue
    case .hz2000:     hz2000 = value.iValue
    case .hz4000:     hz4000 = value.iValue
    case .hz8000:     hz8000 = value.iValue
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Properties
  
  public let id: String

  public var eqEnabled = false
  public var hz63: Int = 0
  public var hz125: Int = 0
  public var hz250: Int = 0
  public var hz500: Int = 0
  public var hz1000: Int = 0
  public var hz2000: Int = 0
  public var hz4000: Int = 0
  public var hz8000: Int = 0
  
  
  public enum Property: String {
    // properties received from the radio
    case eqEnabled = "mode"
    case hz63   = "63hz"
    case hz125  = "125hz"
    case hz250  = "250hz"
    case hz500  = "500hz"
    case hz1000 = "1000hz"
    case hz2000 = "2000hz"
    case hz4000 = "4000hz"
    case hz8000 = "8000hz"
  }

  public enum AlternateProperty: String {
    // properties sent to the radio
    case hz63   = "63Hz"
    case hz125  = "125Hz"
    case hz250  = "250Hz"
    case hz500  = "500Hz"
    case hz1000 = "1000Hz"
    case hz2000 = "2000Hz"
    case hz4000 = "4000Hz"
    case hz8000 = "8000Hz"
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private Properties
  
  private var _initialized = false

  /* ----- from the FlexApi source -----
   eq " + id + "mode="   + 1/0
   eq " + id + "32Hz="   + hz32
   eq " + id + "63Hz="   + hz63
   eq " + id + "125Hz="  + hz125
   eq " + id + "250Hz="  + hz250
   eq " + id + "500Hz="  + hz500
   eq " + id + "1000Hz=" + hz1000
   eq " + id + "2000Hz=" + hz2000
   eq " + id + "4000Hz=" + hz4000
   eq " + id + "8000Hz=" + hz8000
   eq " + id + "info"
   
   // the following are properties on Radio
   eq apf gain=" + apfGain
   eq apf mode=" + apfMode
   eq apf qfactor=" + apfQFactor
   */
}
