//
//  Packet.swift
//  SharedFeature/Packet
//
//  Created by Douglas Adams on 10/28/21
//  Copyright © 2021 Douglas Adams. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - Packet Struct

public struct Packet: Identifiable, Comparable, Equatable, Sendable {
  public static func < (lhs: Packet, rhs: Packet) -> Bool {
      lhs.nickname + lhs.model < rhs.nickname + rhs.model
    }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ source: PacketSource, _ properties: KeyValuesArray) {
    self.source = source
    
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Packet.Property(rawValue: property.key) else {
        // log it and ignore the Key
        apiLog(.propertyWarning, "Packet: Unknown property - \(property.key) = \(property.value)", property.key)
        continue
      }
      self.apply(property: token, value: property.value)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Methods
  
  private mutating func apply(property: Packet.Property, value: String) {
    switch property {
      
      // these fields in the received packet are copied to the Packet struct
    case .availableClients:           availableClients = value.iValue
    case .availablePanadapters:       availablePanadapters = value.iValue
    case .availableSlices:            availableSlices = value.iValue
    case .callsign:                   callsign = value
    case .discoveryProtocolVersion:   discoveryProtocolVersion = value
    case .externalPortLink:           externalPortLink = value.bValue
    case .fpcMac:                     fpcMac = value
    case .guiClientHandles:           guiClientHandles = value.replacingOccurrences(of: "\u{7F}", with: "").valuesArray(delimiter: ",")
    case .guiClientHosts:             guiClientHosts = value.replacingOccurrences(of: "\u{7F}", with: "").valuesArray(delimiter: ",")
    case .guiClientIps:               guiClientIps = value.replacingOccurrences(of: "\u{7F}", with: "").valuesArray(delimiter: ",")
    case .guiClientPrograms:          guiClientPrograms = value.replacingOccurrences(of: "\u{7F}", with: "").valuesArray(delimiter: ",")
    case .guiClientStations:          guiClientStations = value.replacingOccurrences(of: "\u{7F}", with: "").valuesArray(delimiter: ",")
    case .inUseHost, .inUseHostWan:   inUseHost = value
    case .inUseIp, .inUseIpWan:       inUseIp = value
    case .licensedClients:            licensedClients = value.iValue
    case .maxLicensedVersion:         maxLicensedVersion = value
    case .maxPanadapters:             maxPanadapters = value.iValue
    case .maxSlices:                  maxSlices = value.iValue
    case .minSoftwareVersion:         minSoftwareVersion = value
    case .model:                      model = value
    case .nickname, .radioName:       nickname = value
    case .port:                       port = value.iValue
    case .publicIp, .publicIpWan:     publicIp = value
    case .publicTlsPort:              publicTlsPort = value.iValueOpt
    case .publicUdpPort:              publicUdpPort = value.iValueOpt
    case .publicUpnpTlsPort:          publicUpnpTlsPort = value.iValueOpt
    case .publicUpnpUdpPort:          publicUpnpUdpPort = value.iValueOpt
    case .radioLicenseId:             radioLicenseId = value
    case .requiresAdditionalLicense:  requiresAdditionalLicense = value.bValue
    case .serial:                     serial = value
    case .status:                     status = value
    case .upnpSupported:              upnpSupported = value.bValue
    case .version:                    version = value
    case .wanConnected:               wanConnected = value.bValue
      
    case .lastSeen:                   break // ignore this, will only be present in Smartlink properties
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  public var id: String { serial + "|" + publicIp }
  public let source: PacketSource

  public var isPortForwardOn = false
  public var localInterfaceIP = ""
  public var negotiatedHolePunchPort = 0
  public var requiresHolePunch = false
  public var stations = [String]()

  // PACKET TYPE                                       LAN   WAN
  public var availableClients = 0                   //  X
  public var availablePanadapters = 0               //  X
  public var availableSlices = 0                    //  X
  public var callsign = ""                          //  X     X
  public var discoveryProtocolVersion = ""          //  X
  public var externalPortLink = false
  public var fpcMac = ""                            //  X
  public var guiClientHandles = [String]()
  public var guiClientHosts = [String]()
  public var guiClientIps = [String]()
  public var guiClientPrograms = [String]()
  public var guiClientStations = [String]()
  public var inUseHost = ""                         //  X     X
  public var inUseIp = ""                           //  X     X
  public var licensedClients = 0                    //  X
  public var maxLicensedVersion = ""                //  X     X
  public var maxPanadapters = 0                     //  X
  public var maxSlices = 0                          //  X
  public var minSoftwareVersion = ""                //
  public var model = ""                             //  X     X
  public var nickname = ""                          //  X     X   in WAN as "radio_name"
  public var port = 0                               //  X
  public var publicIp = ""                          //  X     X   in LAN as "ip"
  public var publicTlsPort: Int?                    //        X
  public var publicUdpPort: Int?                    //        X
  public var publicUpnpTlsPort: Int?                //        X
  public var publicUpnpUdpPort: Int?                //        X
  public var radioLicenseId = ""                    //  X     X
  public var requiresAdditionalLicense = false      //  X     X
  public var serial = ""                            //  X     X
  public var status = ""                            //  X     X
  public var upnpSupported = false                  //        X
  public var version = ""                           //  X     X
  public var wanConnected = false                   //  X

  private var handles = [String]()
  private var hosts = [String]()
  private var ips = [String]()
  private var programs = [String]()
  
  private enum Property: String {
    case availableClients           = "available_clients"
    case availablePanadapters       = "available_panadapters"
    case availableSlices            = "available_slices"
    case callsign
    case discoveryProtocolVersion   = "discovery_protocol_version"
    case externalPortLink           = "external_port_link"
    case fpcMac                     = "fpc_mac"
    case guiClientHandles           = "gui_client_handles"
    case guiClientHosts             = "gui_client_hosts"
    case guiClientIps               = "gui_client_ips"
    case guiClientPrograms          = "gui_client_programs"
    case guiClientStations          = "gui_client_stations"
    case inUseHost                  = "inuse_host"
    case inUseHostWan               = "inusehost"
    case inUseIp                    = "inuse_ip"
    case inUseIpWan                 = "inuseip"
    case lastSeen                   = "last_seen"
    case licensedClients            = "licensed_clients"
    case maxLicensedVersion         = "max_licensed_version"
    case maxPanadapters             = "max_panadapters"
    case maxSlices                  = "max_slices"
    case minSoftwareVersion         = "min_software_version"
    case model
    case nickname                   = "nickname"
    case port
    case publicIp                   = "ip"
    case publicIpWan                = "public_ip"
    case publicTlsPort              = "public_tls_port"
    case publicUdpPort              = "public_udp_port"
    case publicUpnpTlsPort          = "public_upnp_tls_port"
    case publicUpnpUdpPort          = "public_upnp_udp_port"
    case radioLicenseId             = "radio_license_id"
    case radioName                  = "radio_name"
    case requiresAdditionalLicense  = "requires_additional_license"
    case serial                     = "serial"
    case status
    case upnpSupported              = "upnp_supported"
    case version                    = "version"
    case wanConnected               = "wan_connected"
  }
}
