//
//  LocalListener.swift
//  ApiPackage
//
//  Created by Douglas Adams on 10/28/21
//  Copyright © 2021 Douglas Adams. All rights reserved.
//
//  Modernized December 2025 for improved concurrency and error handling.
//

import Foundation
import CocoaAsyncSocket

private final class ListenerLocalSocketDelegate: NSObject, GCDAsyncUdpSocketDelegate {
    weak var actor: ListenerLocalActor?
    /// Initializes the delegate with an optional actor. The actor can be nil at initialization and assigned later.
    init(actor: ListenerLocalActor?) {
        self.actor = actor
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket,
                  didReceive data: Data,
                  fromAddress address: Data,
                  withFilterContext filterContext: Any?) {
        Task { await actor?.didReceive(data: data, address: address) }
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didCloseWithError error: Error?) {
        Task { await actor?.didCloseWithError(error: error) }
    }
}

/// An actor to encapsulate UDP socket management for local listener.
/// Handles socket creation, binding, receiving, and stopping.
/// Designed to work with ListenerLocal to offload socket operations safely.
actor ListenerLocalActor: NSObject {
  
  private let udpQueue = DispatchQueue(label: "ListenerLocal.udpQ")
  private var udpSocket: GCDAsyncUdpSocket?
  private let delegate: ListenerLocalSocketDelegate
  
  /// A closure to be called on data reception.
  /// This closure runs on the MainActor.
  var onReceiveData: ((Data, Data) -> Void)?
  
  /// Initializes the UDP socket and configures it.
  override init() {
    self.delegate = ListenerLocalSocketDelegate(actor: nil)
    super.init()
    self.delegate.actor = self
    let socket = GCDAsyncUdpSocket(delegate: delegate, delegateQueue: udpQueue)
    socket.setPreferIPv4()
    socket.setIPv6Enabled(false)
    do {
      try socket.enableReusePort(true)
      apiLog(.debug, "Local Listener: socket REUSE enabled")
    } catch let error as NSError {
      apiLog(.error, "Local Listener: socket REUSE, error <\(error.localizedDescription)> code <\(error.code)>")
    }
    self.udpSocket = socket
  }
  
  /// Binds the UDP socket to the specified port and begins receiving.
  /// - Parameter port: The port number to bind the socket to.
  /// - Throws: Errors thrown during binding or receiving.
  func start(port: UInt16) throws {
    guard let socket = udpSocket else {
      throw NSError(domain: "ListenerLocalActor", code: 0, userInfo: [NSLocalizedDescriptionKey: "Socket not initialized"])
    }
    do {
      try socket.bind(toPort: port)
      apiLog(.debug, "Local Listener: socket bound to port <\(port)>")
    } catch let error as NSError {
      apiLog(.error, "Local Listener: Error binding to port <\(port)> <\(error.localizedDescription)> code <\(error.code)>")
      throw error
    }
    do {
      try socket.beginReceiving()
      apiLog(.debug, "Local Listener: socket STARTED")
    } catch let error as NSError {
      apiLog(.error, "Local Listener: Error starting to receive <\(error.localizedDescription)> code <\(error.code)>")
      throw error
    }
  }
  
  /// Stops the UDP socket by closing it and clearing the reference.
  func stop() {
    udpSocket?.close()
    udpSocket = nil
    apiLog(.debug, "Local Listener: socket STOPPED")
  }
  
  // MARK: - Nonisolated delegate callbacks
  
  func didReceive(data: Data, address: Data) {
    Task { [weak self] in
      guard let self else { return }
      await self.onReceiveData?(data, address)
    }
  }
  
  func didCloseWithError(error: Error?) {
    Task { [weak self] in
      guard self != nil else { return }
      if let error = error {
        apiLog(.error, "Local Listener: UDP socket closed with error: \(error.localizedDescription)")
      } else {
        apiLog(.debug, "Local Listener: UDP socket closed gracefully.")
      }
    }
  }
  
  func setOnReceiveData(_ closure: ((Data, Data) -> Void)?) async {
    self.onReceiveData = closure
  }
}

/// Listener implementation that listens for UDP broadcasts from a Flex6000 Radio.
///
/// This class wraps ListenerLocalActor to manage the UDP socket on a background queue,
/// while exposing async/throwing APIs and publishing received data processing on the main actor.
@MainActor
public final class ListenerLocal: NSObject, ObservableObject {
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Creates a ListenerLocal instance bound to the given ApiModel.
  /// - Parameter apiModel: The ApiModel instance to send processed data to.
  public init(_ apiModel: ApiModel) {
    self._api = apiModel
    self.socketActor = ListenerLocalActor()
    super.init()
    
    Task { [weak self] in
      guard let self = self else { return }
      await self.socketActor.setOnReceiveData { data, _ in
        self.handleReceivedData(data)
      }
    }
  }
  
  deinit {
    let actor = socketActor
    Task.detached {
      await actor.setOnReceiveData(nil)
      await actor.stop()
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public API
  
  /// Starts listening on the specified UDP port.
  ///
  /// - Parameter port: The UDP port to bind and listen on.
  /// - Throws: Errors if binding or starting reception fails.
  public func start(port: UInt16) async throws {
    try await socketActor.start(port: port)
  }
  
  /// Stops listening and closes the UDP socket.
  public func stop() async {
    await socketActor.stop()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private
  
  nonisolated private let _api: ApiModel
  
  private let socketActor: ListenerLocalActor
  
  /// Handles data received from the UDP socket.
  /// Decodes VITA packets, validates them, and sends discovery packets to the ApiModel.
  /// - Parameter data: The raw Data received from the socket.
  private func handleReceivedData(_ data: Data) {
    // is it a VITA packet?
    guard let vita = Vita.decode(from: data) else {
      apiLog(.error, "Local Listener: Invalid Vita packet")
      return
    }
    
    // YES, is it a Discovery Packet?
    guard vita.classIdPresent, vita.classCode == .discovery else {
      apiLog(.error, "Local Listener: invalid Discovery Packet")
      return
    }
    
    // YES, Payload is a series of strings of the form <key=value> separated by ' ' (space)
    let payloadString = String(decoding: vita.payloadData, as: UTF8.self).trimmingCharacters(in: .controlCharacters)
    let properties = payloadString.trimmingCharacters(in: CharacterSet(charactersIn: "\0")).keyValuesArray()
    
    // process it
    Task { await MainActor.run { self._api.process(.local, properties, data) } }
  }
}

