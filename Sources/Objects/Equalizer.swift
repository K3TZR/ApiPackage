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
      if index == nil {
        apiModel.equalizers.append(Equalizer(id))
        Task { await ApiLog.debug("Equalizer: <\(id)> ADDED") }
        apiModel.equalizers.last!.parse(Array(properties.dropFirst(1)) )
      } else {
        // parse the properties
        apiModel.equalizers[index!].parse(Array(properties.dropFirst(1)) )
      }


    } else {
      // NO, remove it
      apiModel.equalizers.remove(at: index!)
      Task { await ApiLog.debug("Equalizer: <\(id)> REMOVED") }
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
        Task { await ApiLog.warning("Equalizer: unknown property, \(property.key) = \(property.value)") }
        continue
      }
      // known keys
      switch token {
        
      case .eqEnabled:        eqEnabled = property.value.bValue

      case .hz63:      hz63 = property.value.iValue
      case .hz125:    hz125 = property.value.iValue
      case .hz250:    hz250 = property.value.iValue
      case .hz500:    hz500 = property.value.iValue
      case .hz1000:  hz1000 = property.value.iValue
      case .hz2000:  hz2000 = property.value.iValue
      case .hz4000:  hz4000 = property.value.iValue
      case .hz8000:  hz8000 = property.value.iValue
      }
      // is it initialized?
      if _initialized == false {
        // NO, it is now
        _initialized = true
      }
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

  // ----------------------------------------------------------------------------
  // MARK: - Private Properties
  
  private enum SendableProperty: String {
    // properties sent to the radio
    case eqEnabled = "mode"
    case hZ63   = "63Hz"
    case hZ125  = "125Hz"
    case hZ250  = "250Hz"
    case hZ500  = "500Hz"
    case hZ1000 = "1000Hz"
    case hZ2000 = "2000Hz"
    case hZ4000 = "4000Hz"
    case hZ8000 = "8000Hz"
  }

  private var _initialized = false

  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
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

  public static func set(id: String, property: Property, value: String) -> String {
    var sendableProperty: SendableProperty
    
    switch property {
    case .eqEnabled:  sendableProperty = .eqEnabled
    case .hz63:       sendableProperty = .hZ63
    case .hz125:      sendableProperty = .hZ125
    case .hz250:      sendableProperty = .hZ250
    case .hz500:      sendableProperty = .hZ500
    case .hz1000:     sendableProperty = .hZ1000
    case .hz2000:     sendableProperty = .hZ2000
    case .hz4000:     sendableProperty = .hZ4000
    case .hz8000:     sendableProperty = .hZ8000
    }
    return "eq \(id) \(sendableProperty.rawValue)=\(value)"
  }

  public static func infof(id: String) -> String {
    "eq \(id) info"
  }
}
