//
//  RemoteRxAudio.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 4/5/23.
//

import Foundation

// RemoteRxAudio
//      creates a RemoteRxAudio instance to be used by a Client to support the
//      processing of a UDP stream of Rx Audio from the Radio to the client. The RemoteRxAudio
//      is added / removed by TCP messages.

@MainActor
@Observable
public final class RemoteRxAudio: Identifiable {
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: UInt32) {
    self.id = id
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray) {
    // get the id
    if let id = properties[0].key.streamId {
      // add it if not already present
      if apiModel.remoteRxAudio == nil { apiModel.remoteRxAudio = RemoteRxAudio(id) }
      // parse the properties
      apiModel.remoteRxAudio?.parse( Array(properties.dropFirst(2)) )
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  ///  Parse RemoteRxAudio key/value pairs
  /// - Parameter properties: a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        apiLog(.propertyWarning, "RemoteRxAudio \(self.id.hex): unknown property <\(property.key) = \(property.value)>", property.key)
        continue
      }
      self.apply(property: token, value: property.value)
    }
    // is it initialized?
    if _initialized == false && clientHandle != 0 {
      // NO, it is now
      _initialized = true
      apiLog(.debug, "RemoteRxAudio: ADDED Id <\(self.id.hex)> compression <\(self.compression)> handle <\(self.clientHandle.hex)>") 
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Methods
  
  /// Apply a single property value
  /// - Parameters:
  ///   - property: Property enum value
  ///   - value: String to apply
  private func apply(property: RemoteRxAudio.Property, value: String) {
    switch property {
      
    case .clientHandle: clientHandle = value.handle ?? 0
    case .compression:  compression = value.lowercased()
    case .ip:           ip = value
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Properties
  
  public let id: UInt32
  
  public var clientHandle: UInt32 = 0
  public var compression = ""
  public var ip = ""
  
  public enum Compression : String {
    case opus
    case none
  }
  
  public enum Property: String {
    case clientHandle = "client_handle"
    case compression
    case ip
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Properties
  
  private var _initialized = false
  private var _rxLostPacketCount = 0
  private var _rxPacketCount = 0
  private var _rxSequenceNumber = -1
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  public static func create(compressed: Bool) -> String {
    "stream create type=\(StreamType.remoteRxAudioStream.rawValue) compression=\(compressed ? Compression.opus.rawValue : Compression.none.rawValue)"
  }
  public static func remove(_ id: UInt32) -> String {
    "stream remove \(id.hex)"
  }
}
