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
    guard let _udpSocket else {
      log?.errorExt("LocalListener: Error creating socket")
      return
    }
    _udpSocket.setPreferIPv4()
    _udpSocket.setIPv6Enabled(false)
    do {
      try _udpSocket.enableReusePort(true)
      log?.errorExt("Local Listener: socket REUSE enabled")
    } catch let error as NSError {
      log?.errorExt("Local Listener: socket REUSE, error <\(error.localizedDescription)>, code <(\(error.code)>")
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  public func start(port: UInt16 = 4992, checkInterval: Int = 1, timeout: TimeInterval = 20.0) async {
    do {
      try _udpSocket!.bind(toPort: port)
      log?.debug("Local Listener: socket bound to port <\(port)>")
      try _udpSocket!.beginReceiving()
      log?.debug("Local Listener: socket STARTED")
      
    } catch let error as NSError {
      log?.errorExt("Error starting socket, error <\(error.localizedDescription)>, code <(\(error.code)>")
    }
  }
  
  public func stop() {
    _udpSocket?.close()
    _udpSocket = nil
    log?.debug("Local Listener: socket STOPPED")
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
      log?.errorExt("Local Listener: Invalid Vita packet")
      return
    }
    
    // YES, is it a Discovery Packet?
    guard vita.classIdPresent, vita.classCode == .discovery else {
      log?.errorExt("Local Listener: invalid Discovery Packet")
      return
    }
    // YES, Payload is a series of strings of the form <key=value> separated by ' ' (space)
    let payloadString = String(decoding: vita.payloadData, as: UTF8.self).trimmingCharacters(in: .controlCharacters)
    let properties = payloadString.trimmingCharacters(in: CharacterSet(charactersIn: "\0")).keyValuesArray()
    
    // process it
    Task { await MainActor.run { self._api.process(.local, properties, data) } }
  }
  
  public func udpSocket(_ sock: GCDAsyncUdpSocket, didCloseWithError error: Error?) {
    if let error = error {
      log?.errorExt("Local Listener: UDP socket closed with error: \(error.localizedDescription)")
    } else {
      log?.debug("Local Listener: UDP socket closed gracefully.")
    }
    _udpSocket = nil
  }
}
