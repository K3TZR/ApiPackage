//
//  DaxRxAudio.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 2/24/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// DaxRxAudio
//      creates a DaxRxAudio instance to be used by a Client to support the
//      processing of a UDP stream of Rx Audio from the Radio to the client. THe DaxRxAudio
//      is added / removed by TCP messages. 
@MainActor
@Observable
public final class DaxRxAudio {
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: UInt32) {
    self.id = id
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  //TODO:
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray) {
    
    // get the id
    if let id = properties[0].key.streamId {
      let daxRxAudio: DaxRxAudio
      if let index = apiModel.daxRxAudios.firstIndex(where: { $0.id == id }) {
        // exists, retrieve
        daxRxAudio = apiModel.daxRxAudios[index]
      } else {
        // new, add
        daxRxAudio = DaxRxAudio(id)
        apiModel.daxRxAudios.append(daxRxAudio)
      }
      // parse
      daxRxAudio.parse(Array(properties.dropFirst(1)) )
    }
  }

//  // get the id
//    if let id = properties[0].key.streamId {
//      // add it if not already present
//      if apiModel.daxRxAudios[id] == nil { apiModel.daxRxAudios[id] = DaxRxAudio() }
//      // parse the properties
//      apiModel.daxRxAudios[id]!.parse( Array(properties.dropFirst(1)) )
//    }
//  }
//  
  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    for property in properties {
      // check for unknown keys
      guard let token = Property(rawValue: property.key) else {
        // unknown, log it and ignore the Key
        apiLog(.propertyWarning, "DaxRxAudio: unknown property, \(property.key) = \(property.value)", property.key) 
        continue
      }
      self.apply(property: token, value: property.value)
        //        // do we have a good reference to the GUI Client?
        //        if let handle = radio.findHandle(for: radio.boundClientId) {
        //          // YES,
        //          self.slice = radio.findSlice(letter: property.value, guiClientHandle: handle)
        //          let gain = rxGain
        //          rxGain = 0
        //          rxGain = gain
        //        } else {
        //          // NO, clear the Slice reference and carry on
        //          slice = nil
        //          continue
        //        }
    }
    // is it initialized?
    if _initialized == false && clientHandle != 0 {
      // NO, it is now
      _initialized = true
      apiLog(.debug, "DaxRxAudio: ADDED channel <\(self.daxChannel)> handle <\(self.clientHandle.hex)>") 
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Methods
  
  /// Apply a single property value
  /// - Parameters:
  ///   - property: Property enum value
  ///   - value: String to apply
  private func apply(property: DaxRxAudio.Property, value: String) {
    switch property {
      
    case .clientHandle: clientHandle = value.handle ?? 0
    case .daxChannel:   daxChannel = value.iValue
    case .ip:           ip = value
    case .sliceLetter:  sliceLetter = value
    }
  }

  // ------------------------------------------------------------------------------
  // MARK: - Properties
  
  //  public var audioOutput: RxAudioOutput?
  
  public let id: UInt32
  
  public var clientHandle: UInt32 = 0
  public var ip = ""
  public var sliceLetter = ""
  public var daxChannel = 0
  public var rxGain = 0
  
  public enum Property: String {
    case clientHandle   = "client_handle"
    case daxChannel     = "dax_channel"
    case ip
    case sliceLetter    = "slice"
//    case type
  }
  
  private var _initialized = false
  private var _rxPacketCount      = 0
  private var _rxLostPacketCount  = 0
  private var _rxSequenceNumber   = -1
  
  private static let elementSizeStandard = MemoryLayout<Float>.size
  private static let elementSizeReduced = MemoryLayout<Int16>.size
  private static let channelCount = 2
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  public static func create(channel: Int, compression: String) -> String {
    "stream create type=dax_rx channel=\(channel) compression=\(compression)"
  }
  public static func remove(_ id: UInt32) -> String {
    "stream remove \(id.hex)"
  }
}

