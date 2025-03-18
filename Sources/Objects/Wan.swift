//
//  Wan.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

@MainActor
@Observable
public final class Wan {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init() {}
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  // TODO:
  
  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse status message
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Wan.Property(rawValue: property.key)  else {
        // log it and ignore the Key
        log?.warning("Wan: unknown property, \(property.key) = \(property.value)")
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .serverConnected:      serverConnected = property.value.bValue
      case .radioAuthenticated:   radioAuthenticated = property.value.bValue
      case .publicTlsPort:        publicTlsPort = property.value.iValue
      case .publicUdpPort:        publicUdpPort = property.value.iValue
      case .publicUpnpTlsPort:    publicUpnpTlsPort = property.value.iValue
      case .publicUpnpUdpPort:    publicUpnpUdpPort = property.value.iValue
      case .upnpSupported:        upnpSupported = property.value.bValue
      }
    }
    // is it initialized?
    if _initialized == false {
      // NO, it is now
      _initialized = true
      log?.debug("Wan: initialized ServerConnected = \(self.serverConnected), RadioAuthenticated = \(self.radioAuthenticated)")
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  public internal(set) var radioAuthenticated: Bool = false
  public internal(set) var serverConnected: Bool = false
  public internal(set) var publicTlsPort: Int = -1
  public internal(set) var publicUdpPort: Int = -1
  public internal(set) var publicUpnpTlsPort: Int = -1
  public internal(set) var publicUpnpUdpPort: Int = -1
  public internal(set) var upnpSupported: Bool = false
  
  public enum Property: String {
    case publicTlsPort      = "public_tls_port"
    case publicUdpPort      = "public_udp_port"
    case publicUpnpTlsPort  = "public_upnp_tls_port"
    case publicUpnpUdpPort  = "public_upnp_udp_port"
    case radioAuthenticated = "radio_authenticated"
    case serverConnected    = "server_connected"
    case upnpSupported      = "upnp_supported"
  }
  
  private var _initialized = false

}
