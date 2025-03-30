//
//  LocalListener.swift
//  ApiPackage
//
//  Created by Douglas Adams on 10/28/21
//  Copyright © 2021 Douglas Adams. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

/// Listener implementation
///
///      listens for the udp broadcasts of a Flex6000 Radio
///
public final class ListenerLocal: NSObject, ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ apiModel: ApiModel) {
    _api = apiModel
    super.init()
    
    // create a Udp socket and set options
    _udpSocket = GCDAsyncUdpSocket( delegate: self, delegateQueue: _udpQ )
    _udpSocket!.setPreferIPv4()
    _udpSocket!.setIPv6Enabled(false)
    
    if _udpSocket == nil {
      log?.errorExt("Could not create GCDAsyncUdpSocket")
      fatalError("Could not create GCDAsyncUdpSocket")
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  public func start(port: UInt16 = 4992, checkInterval: Int = 1, timeout: TimeInterval = 20.0) async {
    do {
      try _udpSocket!.enableReusePort(true)
      try _udpSocket!.bind(toPort: port)
      try _udpSocket!.beginReceiving()
      log?.debug("Local Listener: UDP socket STARTED")
      
    } catch {
      log?.errorExt("Error starting UDP socket")
    }
  }
  
  public func stop() {
    _udpSocket?.closeAfterSending()
    log?.debug("Local Listener: UDP socket STOPPED")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  nonisolated private let _api: ApiModel
  
  private let _udpQ = DispatchQueue(label: "ListenerLocal" + ".udpQ")
  private var _udpSocket: GCDAsyncUdpSocket?
}

// ----------------------------------------------------------------------------
// MARK: - GCDAsyncUdpSocketDelegate extension

extension ListenerLocal: GCDAsyncUdpSocketDelegate {
  /// The Socket received data
  ///
  /// - Parameters:
  ///   - sock:           the GCDAsyncUdpSocket
  ///   - data:           the Data received
  ///   - address:        the Address of the sender
  ///   - filterContext:  the FilterContext
  public func udpSocket(_ sock: GCDAsyncUdpSocket,
                        didReceive data: Data,
                        fromAddress address: Data,
                        withFilterContext filterContext: Any?) {
    
    // is it a VITA packet?
    guard let vita = Vita.decode(from: data) else {
      log?.errorExt("NON-Vita packet received")
      return
    }
    
    // YES, is it a Discovery Packet?
    if vita.classIdPresent && vita.classCode == .discovery {
      // YES, Payload is a series of strings of the form <key=value> separated by ' ' (space)
      let payloadString = NSString(bytes: vita.payloadData, length: vita.payloadSize, encoding: String.Encoding.utf8.rawValue)! as String
      // eliminate any Nulls at the end of the payload & form KeyValuesArray
      let properties = payloadString.trimmingCharacters(in: CharacterSet(charactersIn: "\0")).keyValuesArray()
      
      // process it
      Task { await MainActor.run { self._api.process(.local, properties, data) } }
    } else {
      log?.errorExt("Vita received but not a valid Discovery Packet")
    }
  }
  
  public func udpSocket(_ sock: GCDAsyncUdpSocket, didCloseWithError error: Error?) {
    log?.errorExt("\(error?.localizedDescription ?? "No Error Provided")")
    fatalError("UDP socket CLOSED with error")
  }
}
