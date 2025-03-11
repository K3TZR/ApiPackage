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
//@MainActor
public final class ListenerLocal: NSObject, ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  init(_ apiModel: ApiModel) {
    _api = apiModel
    super.init()
    
    _formatter.timeZone = .current
    _formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    
    // create a Udp socket and set options
    _udpSocket = GCDAsyncUdpSocket( delegate: self, delegateQueue: _udpQ )
    _udpSocket!.setPreferIPv4()
    _udpSocket!.setIPv6Enabled(false)
   
    if _udpSocket == nil {
      fatalError("Could not create GCDAsyncUdpSocket")
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  func start(port: UInt16 = 4992, checkInterval: Int = 1, timeout: TimeInterval = 20.0) {
    do {
      try _udpSocket!.enableReusePort(true)
      try _udpSocket!.bind(toPort: port)
      try _udpSocket!.beginReceiving()
      log.info("Local Listener: UDP socket STARTED")
      
    } catch {
      log.error("Error starting UDP socket")
    }

    // Create the timer’s dispatch source
    _pingTimer = DispatchSource.makeTimerSource(queue: _timerQ)
    
    // Setup the timer
    _pingTimer!.schedule(deadline: .now(), repeating: .seconds(checkInterval))
    
    // Set the event handler
    _pingTimer!.setEventHandler  { [weak self] in
      guard let self = self else { return }
      
      Task { await MainActor.run {
        self._api.removeLostRadios(Date(), timeout)
      }}
    }
    
    // Start the timer
    _pingTimer!.resume()
  }
  
  func stop() {
    _pingTimer?.cancel()
    _udpSocket?.closeAfterSending()
    log.info("Local Listener: UDP socket STOPPED")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  nonisolated private let _api: ApiModel
  
  private var _pingTimer: DispatchSourceTimer?
  private let _formatter = DateFormatter()
  private var _success = false
  private let _timerQ = DispatchQueue(label: "ListenerLocal" + ".timerQ", attributes: .concurrent)
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
    guard let vita = Vita.decode(from: data) else { return }
    
    // YES, is it a Discovery Packet?
    if vita.classIdPresent && vita.classCode == .discovery {
      // YES, Payload is a series of strings of the form <key=value> separated by ' ' (space)
      let payloadString = NSString(bytes: vita.payloadData, length: vita.payloadSize, encoding: String.Encoding.utf8.rawValue)! as String
      // eliminate any Nulls at the end of the payload & form KeyValuesArray
      let properties = payloadString.trimmingCharacters(in: CharacterSet(charactersIn: "\0")).keyValuesArray()
      
      // process it
      Task { await MainActor.run { self._api.process(.local, properties, data) } }
    }
  }
  
  public func udpSocket(_ sock: GCDAsyncUdpSocket, didCloseWithError error: Error?) {
    print("----->>>>>", "UDP socket CLOSED with error")
  }
}
