//
//  DaxMicAudio.swift
//  FlexApiFeature/Objects
//
//  Created by Mario Illgen on 27.03.17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// DaxMicAudio
//      creates a DaxMicAudio instance to be used by a Client to support the
//      processing of a UDP stream of Mic Audio from the Radio to the client. The DaxMicAudio
//      is added / removed by TCP messages.
@MainActor
@Observable
public final class DaxMicAudio: Identifiable {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: UInt32) { self.id = id }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray) {
    // get the id
    if let id = properties[0].key.streamId {
      // add it if not already present
      if apiModel.daxMicAudio == nil { apiModel.daxMicAudio = DaxMicAudio(id) }
      // parse the properties
      apiModel.daxMicAudio?.parse( Array(properties.dropFirst(1)) )
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown keys
      guard let token = Property(rawValue: property.key) else {
        // unknown Key, log it and ignore the Key
        Task { await ApiLog.warning("DaxMicAudio \(self.id.hex): unknown property, \(property.key) = \(property.value)") }
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .clientHandle: clientHandle = property.value.handle ?? 0
      case .ip:           ip = property.value
      case .type:         break  // included to inhibit unknown token warnings
      }
    }
    // is it initialized?
    if _initialized == false && clientHandle != 0 {
      // NO, it is now
      _initialized = true
      Task { await ApiLog.debug("DaxMicAudio: ADDED Id <\(self.id.hex)> handle <\(self.clientHandle.hex)>") }
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Public Properties
  
  public let id: UInt32
  
  public var clientHandle: UInt32 = 0
  public var ip = ""
  public var micGain = 0 {
    didSet { if micGain != oldValue {
      var newGain = micGain
      // check limits
      if newGain > 100 { newGain = 100 }
      if newGain < 0 { newGain = 0 }
      if micGain != newGain {
        micGain = newGain
        if micGain == 0 {
          micGainScalar = 0.0
          return
        }
        let db_min:Float = -10.0;
        let db_max:Float = +10.0;
        let db:Float = db_min + (Float(micGain) / 100.0) * (db_max - db_min);
        micGainScalar = pow(10.0, db / 20.0);
      }
    }}}
  public internal(set) var micGainScalar: Float = 0
  
  public enum Property: String {
    case clientHandle = "client_handle"
    case ip
    case type
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Private Properties
  
  private var _initialized = false
  private var _rxLostPacketCount = 0
  private var _rxPacketCount = 0
  private var _rxSequenceNumber = -1
  private var _streamActive = false
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  public static func create() -> String {
    "stream create type=dax_mic"
  }
  public static func remove(_ id: UInt32) -> String {
    "stream remove \(id.hex)"
  }
}
