//
//  Memory.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 8/20/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

@MainActor
@Observable
public final class Memory: Identifiable {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: UInt32) {
    self.id = id
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray, _ inUse: Bool) {
    
    // get the id
    if let id = properties[0].key.objectId {
      let index = apiModel.memories.firstIndex(where: { $0.id == id })
      
      // is it in use?
      if inUse {
        let memory: Memory
        if let index {
          // exists, retrieve
          memory = apiModel.memories[index]
        } else {
          // new, add
          memory = Memory(id)
          apiModel.memories.append(memory)
        }
        // parse
        memory.parse(Array(properties.dropFirst(1)) )
        
      } else {
        // remove
        if let index {
          apiModel.memories.remove(at: index)
          apiLog(.debug, "Memory: REMOVED Id <\(id)>")
        } else {
          apiLog(.debug, "Memory: attempt to remove a non-existing entry")
        }
      }
    }
  }

//  // get the id
//    if let id = properties[0].key.objectId {
//      let index = apiModel.memories.firstIndex(where: { $0.id == id })
//      // is it in use?
//      if inUse {
//        if index == nil {
//          apiModel.memories.append(Memory(id))
//          apiModel.memories.last!.parse(Array(properties.dropFirst(1)) )
//        } else {
//          // parse the properties
//          apiModel.memories[index!].parse(Array(properties.dropFirst(1)) )
//        }
//        
//      } else {
//        // NO, remove it
//        apiModel.memories.remove(at: index!)
//        apiLog(.debug, "Memory: REMOVED Id <\(id)>")
//      }
//    }
//  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Parse method
  
  /// Parse key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Memory.Property(rawValue: property.key) else {
        // log it and ignore the Key
        apiLog(.propertyWarning, "Memory: Id <\(self.id.hex)> unknown property <\(property.key) = \(property.value)>", property.key)
        continue
      }
      self.apply(property: token, value: property.value)
    }
    // is it initialized?
    if _initialized == false {
      // NO, it is now
      _initialized = true
      apiLog(.debug, "Memory: ADDED Id <\(self.id.hex)> name <\(self.name)>")
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Methods
  
  /// Apply a single property value
  /// - Parameters:
  ///   - property: Property enum value
  ///   - value: String to apply
  private func apply(property: Memory.Property, value: String) {
    switch property {
      
    case .digitalLowerOffset:       digitalLowerOffset = value.iValue
    case .digitalUpperOffset:       digitalUpperOffset = value.iValue
    case .frequency:                frequency = value.mhzToHz
    case .group:                    group = value.replacingOccurrences(of: "\u{7F}", with: "").replacingSpaces()
    case .highlight:                break   // ignored here
    case .highlightColor:           break   // ignored here
    case .mode:                     mode = value.replacingOccurrences(of: "\u{7F}", with: "").replacingSpaces()
    case .name:                     name = value.replacingOccurrences(of: "\u{7F}", with: "").replacingSpaces()
    case .owner:                    owner = value.replacingOccurrences(of: "\u{7F}", with: "").replacingSpaces()
    case .repeaterOffsetDirection:  offsetDirection = value.replacingOccurrences(of: "\u{7F}", with: "").replacingSpaces()
    case .repeaterOffset:           offset = value.iValue
    case .rfPower:                  rfPower = value.iValue
    case .rttyMark:                 rttyMark = value.iValue
    case .rttyShift:                rttyShift = value.iValue
    case .rxFilterHigh:             filterHigh = value.iValue
    case .rxFilterLow:              filterLow = value.iValue
    case .squelchEnabled:           squelchEnabled = value.bValue
    case .squelchLevel:             squelchLevel = value.iValue
    case .step:                     step = value.iValue
    case .toneMode:                 toneMode = value.replacingOccurrences(of: "\u{7F}", with: "").replacingSpaces()
    case .toneValue:                toneValue = value.fValue
      
    case .apply, .create, .remove:  break   // ignored here
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Properties
  
  public let id: UInt32
  
  public var digitalLowerOffset = 0
  public var digitalUpperOffset = 0
  public var filterHigh = 0
  public var filterLow = 0
  public var frequency: Hz = 0
  public var group = ""
  public var mode = ""
  public var name = ""
  public var offset = 0
  public var offsetDirection = ""
  public var owner = ""
  public var rfPower = 0
  public var rttyMark = 0
  public var rttyShift = 0
  public var squelchEnabled = false
  public var squelchLevel = 0
  public var step = 0
  public var toneMode = ""
  public var toneValue: Float = 0
  
  public enum Property: String {
    case apply
    case create
    case digitalLowerOffset         = "digl_offset"
    case digitalUpperOffset         = "digu_offset"
    case frequency                  = "freq"
    case group
    case highlight
    case highlightColor             = "highlight_color"
    case mode
    case name
    case owner
    case remove
    case repeaterOffsetDirection    = "repeater"
    case repeaterOffset             = "repeater_offset"
    case rfPower                    = "power"
    case rttyMark                   = "rtty_mark"
    case rttyShift                  = "rtty_shift"
    case rxFilterHigh               = "rx_filter_high"
    case rxFilterLow                = "rx_filter_low"
    case step
    case squelchEnabled             = "squelch"
    case squelchLevel               = "squelch_level"
    case toneMode                   = "tone_mode"
    case toneValue                  = "tone_value"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Properties
  
  private var _initialized = false
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods

  /* ----- from the FlexApi source -----
   memory set " + _index + " digl_offset=" + _diglOffset
   memory set " + _index + " digu_offset=" + _diguOffset
   memory set " + _index + " freq=" + StringHelper.DoubleToString(_freq, "f6")
   memory set " + _index + " group=" + _group.Replace(' ', '\u007f')
   memory set " + _index + " name=" + _name.Replace(' ', '\u007f')
   memory set " + _index + " mode=" + _mode
   memory set " + _index + " owner=" + _owner.Replace(' ', '\u007f')
   memory set " + _index + " power=" + _rfPower
   memory set " + _index + " repeater=" + FMTXOffsetDirectionToString(_offsetDirection)
   memory set " + _index + " repeater_offset=" + StringHelper.DoubleToString(_repeaterOffset, "f6")
   memory set " + _index + " rtty_mark=" + _rttyMark
   memory set " + _index + " rtty_shift=" + _rttyShift
   memory set " + _index + " rx_filter_low=" + _rxFilterLow
   memory set " + _index + " rx_filter_high=" + _rxFilterHigh
   memory set " + _index + " squelch=" + Convert.ToByte(_squelchOn)
   memory set " + _index + " squelch_level=" + _squelchLevel
   memory set " + _index + " step=" + _step
   memory set " + _index + " tone_mode=" + FMToneModeToString(_toneMode)
   memory set " + _index + " tone_value=" + _toneValue
   
   memory apply " + _index
   memory remove " + _index
   
   memory create
   */

  public static func create(id: Int) -> String {
    "memory create"
  }
  public static func apply(id: Int) -> String {
    "memory apply \(id)"
  }
  public static func remove(id: Int) -> String {
    "memory remove \(id)"
  }
  public static func set(id: Int, property: Property, value: String) -> String {
    "memory set \(id) \(property.rawValue)=\(value)"
  }
}

