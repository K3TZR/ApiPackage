//
//  DaxIq.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 3/9/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// DaxIq Class implementation
//      creates an DaxIq instance to be used by a Client to support the
//      processing of a UDP stream of IQ data from the Radio to the client. DaxIq
//      objects are added / removed by TCP messages. They are collected
//      in the apiModel.daxIqs collection.
@MainActor
@Observable
public final class DaxIq {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init() {}
  
  // ----------------------------------------------------------------------------
  // MARK: - Public static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray) {
    // get the id
    if let id = properties[0].key.streamId {
      // add it if not already present
      if apiModel.daxIqs[id] == nil { apiModel.daxIqs[id] = DaxIq() }
      // parse the properties
      apiModel.daxIqs[id]!.parse( Array(properties.dropFirst(1)) )
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      
      guard let token = Property(rawValue: property.key) else {
        // unknown Key, log it and ignore the Key
        Task { await ApiLog.warning("DaxIq: unknown property, \(property.key) = \(property.value)") }
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .clientHandle:     clientHandle = property.value.handle ?? 0
      case .channel:          channel = property.value.iValue
      case .ip:               ip = property.value
      case .isActive:         isActive = property.value.bValue
      case .pan:              pan = property.value.streamId ?? 0
      case .rate:             rate = property.value.iValue
      case .type:             break  // included to inhibit unknown token warnings
      }
    }
    // is it initialized?
    if _initialized == false && clientHandle != 0 {
      // NO, it is now
      _initialized = true
      Task { await ApiLog.debug("DaxIq: ADDED channel <\(self.channel)>") }
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Public Properties
  
  public var delegate: StreamHandler?
  
  public var channel = 0
  public var clientHandle: UInt32 = 0
  public var ip = ""
  public var isActive = false
  public var pan: UInt32 = 0
  public var rate = 0
  
  public enum Property: String {
    case channel        = "daxiq_channel"
    case clientHandle   = "client_handle"
    case ip
    case isActive       = "active"
    case pan
    case rate           = "daxiq_rate"
    case type
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Private Properties
  
  private var _initialized = false
  
  private var _rxPacketCount      = 0
  private var _rxLostPacketCount  = 0
  private var _txSampleCount      = 0
  private var _rxSequenceNumber   = -1
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  public static func create(_ channel: Int) -> String {
    "stream create type=dax_iq channel=\(channel)"
  }
  public static func remove(_ id: UInt32) -> String {
    "stream remove \(id.hex)"
  }
}
