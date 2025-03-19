//
//  Tnf.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 6/30/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

@MainActor
@Observable
public final class Tnf: Identifiable {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization

  public init(_ id: UInt32) {
    self.id = id
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  /* ----- from the FlexApi source -----
   "tnf create freq=" + StringHelper.DoubleToString(_frequency, "f6")
   "tnf remove " + _id
   "tnf set " + _id + " freq=" + StringHelper.DoubleToString(_frequency, "f6")
   "tnf set " + _id + " depth=" + _depth
   "tnf set " + _id + " permanent=" + _permanent
   "tnf set " + _id + " width=" + StringHelper.DoubleToString(_bandwidth, "f6")
   */

  public static func add(at frequency: Hz) -> String {
    "tnf create freq=\(frequency.hzToMhz)"
  }
  public static func remove(id: UInt32) -> String {
    "tnf remove \(id)"
  }
  public static func set(id: UInt32, property: Property, value: String) -> String {
    "tnf set \(id) \(property.rawValue)=\(value)"
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = UInt32(properties[0].key, radix: 10) {
      let index = apiModel.tnfs.firstIndex(where: { $0.id == id })
      // is it in use?
      if inUse {
        // YES, add it if not already present
        if index == nil {
          apiModel.tnfs.append(Tnf(id))
          apiModel.tnfs.last!.parse(Array(properties.dropFirst(1)) )
        } else {
          // parse the properties
          apiModel.tnfs[index!].parse(Array(properties.dropFirst(1)) )
        }
        
      } else {
        // NO, remove it
        apiModel.tnfs.remove(at: index!)
        log?.debug("Tnf \(id): REMOVED")
      }
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse Tnf properties
  /// - Parameter properties: a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Tnf.Property(rawValue: property.key) else {
        // log it and ignore the Key
        log?.warningExt("Tnf: unknown property, \(property.key) = \(property.value)")
        continue
      }
      // known keys
      switch token {
        
      case .depth:      depth = property.value.uValue
      case .frequency:  frequency = property.value.mhzToHz
      case .permanent:  permanent = property.value.bValue
      case .width:      width = property.value.mhzToHz
      }
      // is it initialized?
      if _initialized == false && frequency != 0 {
        // NO, it is now
        _initialized = true
        log?.debug("Tnf: ADDED, frequency = \(self.frequency.hzToMhz)")
      }
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  public let id: UInt32
  
  public private(set) var depth: UInt = 0
  public private(set) var frequency: Hz = 0
  public private(set) var permanent = false
  public private(set) var width: Hz = 0
  
  public enum Property: String {
    case depth
    case frequency = "freq"
    case permanent
    case width
  }
  
  public enum Depth : UInt {
    case normal   = 1
    case deep     = 2
    case veryDeep = 3
  }
  
  private var _initialized = false
}
