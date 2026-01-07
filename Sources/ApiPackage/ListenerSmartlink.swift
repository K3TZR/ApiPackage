//
//  SLListener.swift
//  ApiExplorer
//
//  Created by Douglas Adams on 2/2/25.
//

import Foundation
import SwiftUI

import CocoaAsyncSocket
import JWTDecode

public struct SmartlinkAuthConfig {
  public let domain: URL
  public let clientId: String
  public let authenticateURL: URL
  public let delegationURL: URL
  public let connection: String
  public let device: String
  public let scope: String

  public static let production = SmartlinkAuthConfig(
    domain: URL(string: "https://frtest.auth0.com/")!,
    clientId: "4Y9fEIIsVYyQo5u6jr7yBWc4lV5ugC2m",
    authenticateURL: URL(string: "https://frtest.auth0.com/oauth/ro")!,
    delegationURL: URL(string: "https://frtest.auth0.com/delegation")!,
    connection: "Username-Password-Authentication",
    device: "any",
    scope: "openid offline_access email picture"
  )
}

public enum ListenerError: String, Error {
  case wanConnect = "WanConnect Failed"
  case wanValidation = "WanValidation Failed"
}

/// Listener implementation
///
///      listens for the Smartlink messages of a Flex-6000 Radio
///
@MainActor
public final class ListenerSmartlink: NSObject, ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ apiModel: ApiModel, authConfig: SmartlinkAuthConfig = .production, timeout: Double = 5.0) {
    _apiModel = apiModel
    _authConfig = authConfig
    
    super.init()
    
    _appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "ApiPackage"
    _timeout = timeout
    
    // get a socket & set it's parameters
    _tcpSocket = GCDAsyncSocket(delegate: self, delegateQueue: _socketQ)
    _tcpSocket?.isIPv4PreferredOverIPv6 = true
    _tcpSocket?.isIPv6Enabled = false
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  //  public func start(_ tokens: Tokens) async -> Tokens? {
  //      return connect(tokens)
  //  }
  
  //  public func start(refreshToken: String) async -> Tokens? {
  //    if let idToken = await requestIdToken(refreshToken: refreshToken) {
  //      apiLog(.debug, "Smartlink Listener: IdToken obtained from refresh token")
  //      return connect(using: Tokens(idToken, refreshToken))
  //    }
  //    apiLog(.debug, "Smartlink Listener: Failed to obtain IdToken from refresh token")
  //    return nil
  //  }
  
  /// Start listening given a User / Pwd
  /// - Parameters:
  ///   - user:           user value
  ///   - pwd:            user password
  //  func start(_ user: String, _ pwd: String) async -> Tokens? {
  //    if let tokens = await requestTokens(user: user, pwd: pwd) {
  //      apiLog(.debug, "Smartlink Listener: IdToken obtained from login credentials")
  //      return connect(using: tokens)
  //    }
  //    apiLog(.debug, "Smartlink Listener: Failed to obtain IdToken from login credentials")
  //    return nil
  //  }
  
  /// stop the listener
  public func stop() {
    _state = .stopping
    _pingTimer?.cancel()
    _pingTimer = nil
    //    _tcpSocket?.disconnect()
    _tcpSocket?.disconnectAfterReadingAndWriting()
    apiLog(.debug, "Smartlink Listener: STOPPED")
    _state = .disconnected
  }
  
  /// Initiate a smartlink connection to a radio
  /// - Parameters:
  ///   - serialNumber:       the serial number of the Radio
  ///   - holePunchPort:      the negotiated Hole Punch port number
  /// - Returns:              a WanHandle
  public func smartlinkConnect(for serial: String, holePunchPort: Int) async throws -> String {
    
    return try await withCheckedThrowingContinuation{ continuation in
      _awaitWanHandle = continuation
      apiLog(.debug, "Smartlink Listener: Connect sent to serial <\(serial)>")
      // send a command to SmartLink to request a connection to the specified Radio
      sendTlsCommand("application connect serial=\(serial) hole_punch_port=\(holePunchPort)")
    }
  }
  
  /// Disconnect a smartlink Radio
  /// - Parameter serialNumber:         the serial number of the Radio
  public func smartlinkDisconnect(for serial: String) {
    apiLog(.debug, "Smartlink Listener: Disconnect sent to serial <\(serial)>")
    // send a command to SmartLink to request disconnection from the specified Radio
    sendTlsCommand("application disconnect_users serial=\(serial)")
  }
  
  /// Disconnect a single smartlink Client
  /// - Parameters:
  ///   - serialNumber:         the serial number of the Radio
  ///   - handle:               the handle of the Client
  public func smartlinkDisconnectClient(for serial: String, handle: UInt32) {
    apiLog(.debug, "Smartlink Listener: Disconnect sent to serial <\(serial)> handle <\(handle.hex)>")
    // send a command to SmartLink to request disconnection from the specified Radio
    sendTlsCommand("application disconnect_users serial=\(serial) handle=\(handle.hex)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  public func connect(_ tokens: Tokens) -> Bool {
    _currentTokens = tokens
    _state = .connecting
    // use the ID Token to connect to the Smartlink service
    guard let socket = _tcpSocket else {
      apiLog(.error, "Smartlink Listener: Socket not initialized")
      _state = .disconnected
      return false
    }
    do {
      try socket.connect(toHost: kSmartlinkHost, onPort: kSmartlinkPort, withTimeout: _timeout)
      apiLog(.debug, "Smartlink Listener: TCP Socket connection initiated")
      return true
      
    } catch {
      apiLog(.debug, "Smartlink Listener: TCP Socket connection FAILED")
      _state = .disconnected
      return false
    }
  }
  
  private func readData() {
    _tcpSocket?.readData(to: GCDAsyncSocket.lfData(), withTimeout: -1, tag: 0)
  }
  
  /// Test connection
  /// - Parameter serialNumber:         the serial number of the Radio
  ///
  public func sendSmartlinkTest(for serialNumber: String) {
    // insure that the WanServer is connected to SmartLink
    apiLog(.info, "Smartlink Listener:, smartLink test initiated to serial <\(serialNumber)>")
    
    // send a command to SmartLink to test the connection for the specified Radio
    sendTlsCommand("application test_connection serial=\(serialNumber)", timeout: _timeout)
  }
  
  /// Send a command to the server using TLS
  /// - Parameter cmd:                command text
  private func sendTlsCommand(_ cmd: String, timeout: TimeInterval = 5.0, tag: Int = 1) {
    if _state != .ready {
      apiLog(.warning, "Smartlink Listener: sending TLS command while state=\(_state)")
    }
    // send the specified command to the SmartLink server using TLS
    let command = cmd + "\n"
    _tcpSocket?.write(command.data(using: .utf8, allowLossyConversion: false) ?? Data(), withTimeout: timeout, tag: tag)
  }
  
  /// Ping the SmartLink server
  private func startPinging() {
    if _pingTimer != nil { return }
    // create the timer's dispatch source
    _pingTimer = DispatchSource.makeTimerSource(queue: _pingQ)
    
    // Setup the timer
    _pingTimer?.schedule(deadline: .now() + .seconds(10), repeating: .seconds(10))
    
    // set the event handler
    _pingTimer?.setEventHandler(handler: { [self] in
      // send another Ping
      sendTlsCommand("ping from client", timeout: -1)
    })
    // start the timer
    _pingTimer?.resume()
    apiLog(.debug, "Smartlink Listener: STARTED pinging")
  }
  
  private func startTLS(_ tlsSettings: [String : NSObject]) {
    _tcpSocket?.startTLS(tlsSettings)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  private enum ConnectionState { case disconnected, connecting, tlsSecuring, ready, stopping }
  
  private var _authConfig: SmartlinkAuthConfig
  private var _state: ConnectionState = .disconnected
  
  private var _appName: String?
  private var _awaitWanHandle: CheckedContinuation<String, Error>?
  private var _callsign: String?
  private var _currentTokens: Tokens?
  private var _domain: String?
  private var _firstName: String?
  private var _host: String?
  private var _lastName: String?
  private let _apiModel: ApiModel!
  private let _pingQ = DispatchQueue(label: "SmartlinkListener.pingQ")
  private var _pingTimer: DispatchSourceTimer?
  private var _platform: String?
  private var _previousIdToken: IdToken?
  private var _publicIp: String?
  private var _pwd: String?
  private var _serial: String?
  private var _smartlinkImage: Image?
  private let _socketQ = DispatchQueue(label: "WanListener.socketQ")
  private var _tcpSocket: GCDAsyncSocket?
  private var _timeout = 0.0                // seconds
  private var _user: String?
  private var _wanHandle: String?
  
  private let kSmartlinkHost = "smartlink.flexradio.com"
  private let kSmartlinkPort: UInt16 = 443
  private let kPlatform = "macOS"
  
  private let kApplicationJson    = "application/json"
  private let kHttpHeaderField    = "content-type"
  private let kHttpPost           = "POST"
  private let kGrantType          = "password"
  private let kGrantTypeRefresh   = "refresh_token"
  
  private let kKeyClientId        = "client_id"       // dictionary keys
  private let kKeyConnection      = "connection"
  private let kKeyDevice          = "device"
  private let kKeyGrantType       = "grant_type"
  private let kKeyIdToken         = "id_token"
  private let kKeyPassword        = "password"
  private let kKeyRefreshToken    = "refresh_token"
  private let kKeyScope           = "scope"
  private let kKeyTarget          = "target"
  private let kKeyUserName        = "username"
  
  private let kDefaultPicture     = "person.fill"
  private let kClaimPicture       = "picture"
  private let kClaimEmail         = "email"
}

// ----------------------------------------------------------------------------
// MARK: - ListenerSmartlink extension - GCDAsyncSocketDelegate

extension ListenerSmartlink: GCDAsyncSocketDelegate {
  //      All are called on the _socketQ
  //
  //      1. A TCP connection is opened to the SmartLink server
  //      2. A TLS connection is then initiated over the TCP connection
  //      3. The TLS connection "secures" and is now ready for use
  //
  //      If a TLS negotiation fails (invalid certificate, etc) then the socket will immediately close,
  //      and the socketDidDisconnect:withError: delegate method will be called with an error code.
  //
  public nonisolated func socket(_ sock: GCDAsyncSocket,
                     didConnectToHost host: String,
                     port: UInt16) {
//    _host = host
    apiLog(.debug, "Smartlink Listener: TCP Socket didConnectToHost <\(host):\(port)>")
    
    // initiate a secure (TLS) connection to the Smartlink server
    var tlsSettings = [String : NSObject]()
    tlsSettings[kCFStreamSSLPeerName as String] = kSmartlinkHost as NSObject
    
    Task {
      await startTLS(tlsSettings)
      apiLog(.debug, "Smartlink Listener: TLS Socket connection initiated")
      await MainActor.run { _state = .tlsSecuring }
    }
  }
  
  public nonisolated func socketDidSecure(_ sock: GCDAsyncSocket) {
    
    Task {
      apiLog(.debug, "Smartlink Listener: TLS socketDidSecure")
      
      // start pinging SmartLink server
      await startPinging()
      
      if let appName = await _appName, let token = await _currentTokens?.idToken {
        await sendTlsCommand("application register name=\(appName) platform=\(kPlatform) token=\(token)", timeout: _timeout, tag: 0)
        apiLog(.debug, "Smartlink Listener: Application registered, name <\(appName)> platform <\(kPlatform)>")
      } else {
        apiLog(.error, "Smartlink Listener: Missing appName or idToken during registration")
      }
      
      // start reading
      await readData()

      apiLog(.info, "Smartlink Listener: STARTED")
      await MainActor.run { _state = .ready }
    }
  }
  
  public nonisolated func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
    // get the bytes that were read
    if let msg = String(data: data, encoding: .ascii) {
      // process the message
      Task { await parseVitaPayload(msg) }
    }
    // trigger the next read
    Task { await readData() }
  }
  
  public nonisolated func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
    // Disconnected from the Smartlink server
    let error = (err == nil ? "" : " with error: " + err!.localizedDescription)
    if err == nil {
      apiLog(.debug, "SmartlinkListener: TCP socketDidDisconnect")
    } else {
      apiLog(.error, "SmartlinkListener: TCP socketDidDisconnect <\(error)>")
    }
    Task { await MainActor.run { _state = .disconnected } }
//    if err != nil { stop() }
  }
  
  public nonisolated func socket(_ sock: GCDAsyncSocket, shouldTimeoutWriteWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
    return 0
  }
  
  public nonisolated func socket(_ sock: GCDAsyncSocket, shouldTimeoutReadWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
    return 30.0
  }
}

// ----------------------------------------------------------------------------
// MARK: - ListenerSmartlink extension - Smartlink authentication

extension ListenerSmartlink {
  
  private struct TokenResponse: Decodable {
    let id_token: String?
    let refresh_token: String?
  }
  
  /// Given a UserId / Password, request an ID Token & Refresh Token
  /// - Parameters:
  ///   - user:       User name
  ///   - pwd:        User password
  /// - Returns:      an Id Token (if any)
  public func requestTokens(_ user: String, _ password: String) async -> Tokens? {
    let url = _authConfig.authenticateURL
    // build the request
    var request = URLRequest(url: url)
    request.httpMethod = kHttpPost
    request.addValue(kApplicationJson, forHTTPHeaderField: kHttpHeaderField)
    
    // add the body data & perform the request
    if let data = createTokensBodyData(user: user, password: password) {
      request.httpBody = data
      
      do {
        let result: TokenResponse = try await performRequest(request)
        if let id = result.id_token, isValid(id) {
          updateClaims(from: id)
          if let refresh = result.refresh_token {
            return Tokens(id, refresh)
          }
        }
        return nil
      } catch {
        apiLog(.error, "Smartlink Listener: Token request failed <\(error)>")
        return nil
      }
    }
    // invalid Id Token or request failure
    return nil
  }
  
  /// Given a Refresh Token, request an ID Token
  /// - Parameter refreshToken:     a Refresh Token
  /// - Returns:                    an Id Token (if any)
  public func requestIdToken(refreshToken: String) async -> IdToken? {
    let url = _authConfig.delegationURL
    // build the request
    var request = URLRequest(url: url)
    request.httpMethod = kHttpPost
    request.addValue(kApplicationJson, forHTTPHeaderField: kHttpHeaderField)
    
    // add the body data & perform the request
    if let data = createRefreshTokenBodyData(for: refreshToken) {
      request.httpBody = data
      do {
        let result: TokenResponse = try await performRequest(request)
        if let id = result.id_token, isValid(id) {
          updateClaims(from: id)
          return id
        }
        return nil
      } catch {
        apiLog(.error, "Smartlink Listener: IdToken refresh failed <\(error)>")
        return nil
      }
    }
    // invalid Id Token
    return nil
  }
  
  /// Validate an Id Token
  /// - Parameter idToken:        the Id Token
  /// - Returns:                  true / false
  public func isValid(_ idToken: IdToken?) -> Bool {
    if let token = idToken, let jwt = try? decode(jwt: token) {
      return jwt.expired == false
    }
    return false
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Perform a URL Request
  /// - Parameter urlRequest:     the Request
  /// - Returns:                  a Decoded type
  private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
    let (responseData, response) = try await URLSession.shared.data(for: request)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(T.self, from: responseData)
  }
  
  /// Create the Body Data for obtaining an Id Token give a Refresh Token
  /// - Returns:                    the Data (if created)
  private func createRefreshTokenBodyData(for refreshToken: String) -> Data? {
    var dict = [String : String]()
    
    dict[kKeyClientId]      = _authConfig.clientId
    dict[kKeyGrantType]     = kGrantTypeRefresh
    dict[kKeyRefreshToken]  = refreshToken
    dict[kKeyTarget]        = _authConfig.clientId
    dict[kKeyScope]         = _authConfig.scope
    
    return serialize(dict)
  }
  
  /// Create the Body Data for obtaining an Id Token given a User Id / Password
  /// - Returns:                    the Data (if created)
  private func createTokensBodyData(user: String, password: String) -> Data? {
    var dict = [String : String]()
    
    dict[kKeyClientId]      = _authConfig.clientId
    dict[kKeyConnection]    = _authConfig.connection
    dict[kKeyDevice]        = _authConfig.device
    dict[kKeyGrantType]     = kGrantType
    dict[kKeyPassword]      = password
    dict[kKeyScope]         = _authConfig.scope
    dict[kKeyUserName]      = user
    
    return serialize(dict)
  }
  
  /// Convert a JSON dictionary to a Data
  /// - Parameter dict:   the dictionary
  /// - Returns:          a Data
  private func serialize(_ dict: Dictionary<String,String>) -> Data? {
    // try to serialize the data
    return try? JSONSerialization.data(withJSONObject: dict)
  }
  
  /// Update the Smartlink picture and email
  /// - Parameter idToken:    the Id Token
  private func updateClaims(from idToken: IdToken?) {
    if let idToken = idToken, let jwt = try? decode(jwt: idToken) {
      Task { [weak self] in
        guard let self else { return }
        let image = await self.getImage(jwt.claim(name: kClaimPicture).string)
        await MainActor.run { self._smartlinkImage = image }
      }
    }
    //      settingModel.shared.smartlinkUser = jwt.claim(name: kClaimEmail).string ?? ""
  }
  
  
  private func getImage(_ claimString: String?) async -> Image {
    guard let urlString = claimString, let url = URL(string: urlString) else {
      return Image(systemName: kDefaultPicture)
    }
    
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      if let image = imageFromData(data) {
        return image
      } else {
        return Image(systemName: kDefaultPicture)
      }
      
    } catch {
      apiLog(.error, "Smartlink Listener: Error loading image <\(error)>")
    }
    return Image(systemName: kDefaultPicture)
  }
  
  func imageFromData(_ data: Data) -> Image? {
#if os(macOS)
    if let nsImage = NSImage(data: data) {
      return Image(nsImage: nsImage)
    }
#else
    if let uiImage = UIImage(data: data) {
      return Image(uiImage: uiImage)
    }
#endif
    return nil
  }
  
}

// ----------------------------------------------------------------------------
// MARK: - ListenerSmartlink extension - Smartlink data Parsing

extension ListenerSmartlink {
  
  /// Parse a Vita payload
  /// - Parameter text:   a Vita payload
  func parseVitaPayload(_ text: String) {
    enum Property: String {
      case application
      case radio
      case Received
    }
    let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
    
    let properties = msg.keyValuesArray()
    guard let first = properties.first, let token = Property(rawValue: first.key) else {
      // log it
      apiLog(.warning, "Smartlink Listener: unknown or malformed message property <\(msg)>")
      return
    }
    // which primary message type?
    switch token {
      
    case .application:    parseApplication(Array(properties.dropFirst()))
    case .radio:          parseRadio(Array(properties.dropFirst()), msg: msg)
    case .Received:       break   // ignore message on Test connection
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Parse a received "application" message
  /// - Parameter properties:        message KeyValue pairs
  private func parseApplication(_ properties: KeyValuesArray) {
    enum Property: String {
      case info
      case registrationInvalid = "registration_invalid"
      case userSettings        = "user_settings"
    }
    
    guard let first = properties.first, let token = Property(rawValue: first.key) else {
      apiLog(.warning, "Smartlink Listener: unknown application property <\(properties.first?.key ?? "")>")
      return
    }
    switch token {
      
    case .info:                     parseApplicationInfo(Array(properties.dropFirst()))
    case .registrationInvalid:      parseRegistrationInvalid(properties)
    case .userSettings:             parseUserSettings(Array(properties.dropFirst()))
    }
  }
  
  /// Parse a received "radio" message
  /// - Parameter msg:        the message (after the primary type)
  private func parseRadio(_ properties: KeyValuesArray, msg: String) {
    enum Property: String {
      case connectReady   = "connect_ready"
      case list
      case testConnection = "test_connection"
    }
    
    guard let first = properties.first, let token = Property(rawValue: first.key) else {
      apiLog(.warning, "Smartlink Listener: unknown radio property <\(properties.first?.key ?? "")>")
      return
    }
    // which secondary message type?
    switch token {
      
    case .connectReady:
      parseRadioConnectReady(Array(properties.dropFirst()))
    case .list:               parseRadioList(msg.dropFirst(11))
    case .testConnection:     parseTestConnectionResults(Array(properties.dropFirst()))
    }
  }
  
  /// Parse a received "application" message
  /// - Parameter properties:         a KeyValuesArray
  private func parseApplicationInfo(_ properties: KeyValuesArray) {
    enum Property: String {
      case publicIp = "public_ip"
    }
    
    apiLog(.debug, "Smartlink Listener: ApplicationInfo received")
    
    // process each key/value pair, <key=value>
    for property in properties {
      guard let token = Property(rawValue: property.key) else {
        apiLog(.warning, "Smartlink Listener: unknown info property <\(property.key)>")
        continue
      }
      switch token {
        
      case .publicIp:       _publicIp = property.value
      }
      if _publicIp != nil {
        // stream it
        
        // NOTE:
        //        Task {
        //        _listenerModel.statusUpdate(WanStatus(.publicIp, _firstName! + " " + _lastName!, _callsign!, _serial, _wanHandle, _publicIp))
        //        }
      }
    }
  }
  
  /// Respond to an Invalid registration
  /// - Parameter msg:                the message text
  private func parseRegistrationInvalid(_ properties: KeyValuesArray) {
    apiLog(.warning, "Smartlink Listener: invalid registration \(properties.count == 3 ? "<\(properties[2].key)>" : "<>")")
  }
  
  /// Parse a received "user settings" message
  /// - Parameter properties:         a KeyValuesArray
  private func parseUserSettings(_ properties: KeyValuesArray) {
    enum Property: String {
      case callsign
      case firstName    = "first_name"
      case lastName     = "last_name"
    }
    
    apiLog(.debug, "Smartlink Listener: UserSettings received")
    
    // process each key/value pair, <key=value>
    for property in properties {
      guard let token = Property(rawValue: property.key) else {
        apiLog(.warning, "Smartlink Listener: unknown user setting <\(property.key)>")
        continue
      }
      switch token {
        
      case .callsign:       _callsign = property.value
      case .firstName:      _firstName = property.value
      case .lastName:       _lastName = property.value
      }
    }
    
    if _firstName != nil && _lastName != nil && _callsign != nil {
      // NOTE:
      //      Task {
      //      _listenerModel.statusUpdate(WanStatus(.settings, _firstName! + " " + _lastName!, _callsign!, _serial, _wanHandle, _publicIp))
      //      }
    }
  }
  
  /// Parse a received "connect ready" message
  /// - Parameter properties:         a KeyValuesArray
  private func parseRadioConnectReady(_ properties: KeyValuesArray) {
    enum Property: String {
      case handle
      case serial
    }
    
    apiLog(.debug, "Smartlink Listener: ConnectReady received")
    
    for property in properties {
      guard let token = Property(rawValue: property.key) else {
        apiLog(.warning, "Smartlink Listener: unknown connect property, \(property.key)")
        continue
      }
      switch token {
        
      case .handle:         _wanHandle = property.value
      case .serial:         _serial = property.value
      }
    }
    if let wanHandle = _wanHandle, let _ = _serial {
      _awaitWanHandle?.resume(returning: wanHandle)
    } else {
      _awaitWanHandle?.resume(throwing: ListenerError.wanConnect)
    }
    _awaitWanHandle = nil
  }
  
  /// Parse a received "radio list" message
  /// - Parameter msg:        the list
  private func parseRadioList(_ msg: String.SubSequence) {
    var publicTlsPortToUse: Int?
    var publicUdpPortToUse: Int?
    
    // Several radios are possible, separate list into its components
    let radioMessages = msg.components(separatedBy: "|")
    
    for message in radioMessages where !message.isEmpty {
      var packet = Packet(.smartlink, message.keyValuesArray())
      
      // Prefer manually defined forwarded ports if available
      if let tlsPort = packet.publicTlsPort, let udpPort = packet.publicUdpPort {
        publicTlsPortToUse = tlsPort
        publicUdpPortToUse = udpPort
        packet.isPortForwardOn = true
      } else if packet.upnpSupported,
                let tlsPort = packet.publicUpnpTlsPort,
                let udpPort = packet.publicUpnpUdpPort {
        publicTlsPortToUse = tlsPort
        publicUdpPortToUse = udpPort
        packet.isPortForwardOn = false
      }
      
      if !packet.upnpSupported && !packet.isPortForwardOn {
        // TODO: Check NAT for preserve_ports — necessary for hole punching
        packet.requiresHolePunch = true
      }
      
      packet.publicTlsPort = publicTlsPortToUse
      packet.publicUdpPort = publicUdpPortToUse
      
      if let localAddr = _tcpSocket?.localHost {
        packet.localInterfaceIP = localAddr
      }
      
      // Process the packet
      _apiModel?.process(.smartlink, message.keyValuesArray(), nil)
      
      // Log the parsed packet
      let nickname = packet.nickname
      apiLog(.debug, "Smartlink Listener: Radio <\(nickname)> parsed")
    }
  }
  
  /// Parse a received "test results" message
  /// - Parameter properties:         a KeyValuesArray
  private func parseTestConnectionResults(_ properties: KeyValuesArray) {
    enum Property: String {
      case forwardTcpPortWorking = "forward_tcp_port_working"
      case forwardUdpPortWorking = "forward_udp_port_working"
      case natSupportsHolePunch  = "nat_supports_hole_punch"
      case radioSerial           = "serial"
      case upnpTcpPortWorking    = "upnp_tcp_port_working"
      case upnpUdpPortWorking    = "upnp_udp_port_working"
    }
    
    var result = SmartlinkTestResult()
    
    // process each key/value pair, <key=value>
    for property in properties {
      guard let token = Property(rawValue: property.key) else {
        apiLog(.warning, "Smartlink Listener: unknown testConnection property <\(property.key)>")
        continue
      }
      
      switch token {
        
      case .forwardTcpPortWorking:      result.forwardTcpPortWorking = property.value.tValue
      case .forwardUdpPortWorking:      result.forwardUdpPortWorking = property.value.tValue
      case .natSupportsHolePunch:       result.natSupportsHolePunch = property.value.tValue
      case .radioSerial:                result.radioSerial = property.value
      case .upnpTcpPortWorking:         result.upnpTcpPortWorking = property.value.tValue
      case .upnpUdpPortWorking:         result.upnpUdpPortWorking = property.value.tValue
      }
      
      Task { [newResult = result] in
        await MainActor.run {
          _apiModel.smartlinkTestResult = newResult
        }
      }
    }
    // log the result
    if result.success {
      apiLog(.info, "Smartlink Listener: Test <SUCCESS>")
    } else {
      apiLog(.info, "Smartlink Listener: Test <FAILURE>")
    }
  }
}

