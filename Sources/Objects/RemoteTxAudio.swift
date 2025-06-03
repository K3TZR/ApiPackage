//
//  RemoteTxAudio.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 2/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

// RemoteTxAudio
//      creates a RemoteTxAudio instance to be used by a Client to support the
//      processing of a UDP stream of Tx Audio from the client to the Radio. The RemoteTxAudio
//      is added / removed by TCP messages.
@MainActor
@Observable
public final class RemoteTxAudio: Identifiable {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: UInt32) { self.id = id }

  // ----------------------------------------------------------------------------
  // MARK: - Public Static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray) {
    // get the id
    if let id = properties[0].key.streamId {
      // add it if not already present
      if apiModel.remoteTxAudio == nil {
        apiModel.remoteTxAudio = RemoteTxAudio(id)
      }
      // parse the properties
      apiModel.remoteTxAudio?.parse( Array(properties.dropFirst(2)) )
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  ///  Parse  key/value pairs
  /// - Parameter properties: a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        Task { await ApiLog.warning("RemoteTxAudio: Id <\(self.id.hex)> unknown property <\(property.key) = \(property.value)>") }
        continue
      }
      // known Keys, in alphabetical order
      switch token {
        
        // Note: only supports "opus", not sure why the compression property exists (future?)
        
      case .clientHandle: clientHandle = property.value.handle ?? 0
      case .compression:  compression = property.value.lowercased()
      case .ip:           ip = property.value
      }
    }
    // is it initialized?
    if _initialized == false && clientHandle != 0 {
      // NO, it is now
      _initialized = true
      Task { await ApiLog.debug("RemoteTxAudio: ADDED Id <\(self.id.hex)> handle <\(self.clientHandle.hex)>") }
    }
  }

  public func start() {
   
  }
  
  public func stop() -> UInt32 {
    return id
  }

  /// Send Tx Audio to the Radio
  /// - Parameters:
  ///   - buffer:             array of encoded audio samples
  /// - Returns:              success / failure
  public func sendAudio(_ udp: Udp, buffer: [UInt8], samples: Int) {
    
    // FIXME: This assumes Opus encoded audio
    
    // get an OpusTx Vita
    if _vita == nil { _vita = Vita(type: .opusTx, streamId: id) }
    
    // create new array for payload (interleaved L/R samples)
    _vita!.payloadData = buffer
    
    // set the length of the packet
    _vita!.payloadSize = samples                                              // 8-Bit encoded samples
    _vita!.packetSize = _vita!.payloadSize + MemoryLayout<Vita.VitaHeader>.size    // payload size + header size
    
    // set the sequence number
    _vita!.sequence = _txSequenceNumber
    
    // encode the Vita class as data and send to radio
    
    // FIXME: need sequence number ????
    
    if let vitaData = Vita.encodeAsData(_vita!, sequenceNumber: 0x00) {
      udp.send(vitaData)
    }
    // increment the sequence number (mod 16)
    _txSequenceNumber = (_txSequenceNumber + 1) % 16    
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Public Properties
  
  public let id : UInt32
  
  public var clientHandle: UInt32 = 0
  public var compression = ""
  public var ip = ""
  
  public enum Property: String {
    case clientHandle = "client_handle"
    case compression
    case ip
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Private Properties
  
  private var _initialized = false
  private var _txSequenceNumber = 0
  private var _vita: Vita?
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  public static func create(compression: String) -> String {
    "stream create type=remote_audio_tx compression=\(compression)"
  }
  public static func remove(_ id: UInt32) -> String {
    "stream remove \(id.hex)"
  }
}
