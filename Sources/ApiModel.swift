//
//  ObjectModel.swift
//
//
//  Created by Douglas Adams on 10/22/23.
//

import Foundation
import os

public typealias IdToken = String
public typealias RefreshToken = String

public struct Tokens: Sendable {
  public var idToken: String
  public var refreshToken: String?
  
  public init(_ idToken: String, _ refreshToken: String?) {
    self.idToken = idToken
    self.refreshToken = refreshToken
  }
}

public struct PickerSelection: Equatable, Codable, Sendable {
  public var radioId: String
  public var station: String
  public var disconnectHandle: String?
  
  public init(_ radioId: String, _ station: String, _ disconnectHandle: String? = nil) {
    self.radioId = radioId
    self.station = station
    self.disconnectHandle = disconnectHandle
  }
}

@MainActor
@Observable
final public class ApiModel: TcpProcessor {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init() {
    streamModel = StreamModel(self)
    _tcp.setDelegate(self)
    _udp.setDelegate(streamModel!)
    timeoutStart()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public let apiLog = ApiLog.shared
  
  public var streamModel: StreamModel?
  
  public internal(set) var connectionIsGui = false
  public var activeSelection: PickerSelection?
  public var activeStation: String?
  public internal(set) var activeSlice: Slice?
  public internal(set) var boundClientId: String?
  public internal(set) var clientInitialized = false
  public internal(set) var connectionHandle: UInt32?
  public internal(set) var hardwareVersion: String?
  //  public internal(set) var radio: Radio?
  public var smartlinkTestResult = SmartlinkTestResult()
  public var testDelegate: TcpProcessor?
  
  // single objects
  public var atu = Atu()
  public var cwx = Cwx()
  public var gps = Gps()
  public var interlock = Interlock()
  public var remoteRxAudio: RemoteRxAudio?
  public var remoteTxAudio: RemoteTxAudio?
  public var transmit = Transmit()
  public var wan = Wan()
  public var waveform = Waveform()
  
  // collection objects
  public var amplifiers = [Amplifier]()
  public var bandSettings = [BandSetting]()
  public var equalizers = [Equalizer]()
  public var guiClients = [GuiClient]()
  public var memories = [Memory]()
  public var meters = [Meter]()
  public var panadapters = [Panadapter]()
  public var profiles = [Profile]()
  public var radios = [Radio]()
  public var slices = [Slice]()
  public var tnfs = [Tnf]()
  public var usbCables = [UsbCable]()
  public var waterfalls = [Waterfall]()
  public var xvtrs = [Xvtr]()
  
  // single stream objects
  public var daxMicAudio: DaxMicAudio?
  public var daxTxAudio: DaxTxAudio?
  //  public var meterStream: MeterStream?
  //  public var remoteTxAudioStream: RemoteTxAudioStream?
  
  // collection stream objects
  public var daxIqs = [UInt32:DaxIq]()
  public var daxRxAudios = [UInt32:DaxRxAudio]()
  //  public var panadapterStreams = [UInt32:PanadapterStream]()
  //  public var waterfallStreams = [UInt32:WaterfallStream]()
  
  // Listeners
  public var listenerSmartlink: ListenerSmartlink?
  public var listenerLocal: ListenerLocal?
  
  @ObservationIgnored
  public var pingIntervals: [TimeInterval] = Array(repeating: 0.0, count: 60)
  @ObservationIgnored
  public var pingIntervalIndex = 0
  
  // ----------------------------------------------------------------------------
  // MARK: - Public types
  
  public enum ObjectType: String {
    case amplifier
    case atu
    case bandSetting = "band"
    case client
    case cwx
    case display
    case equalizer = "eq"
    case gps
    case interlock
    case memory
    case meter
    case panadapter = "pan"
    case profile
    case radio
    case slice
    case stream
    case tnf
    case transmit
    case usbCable = "usb_cable"
    case wan
    case waterfall
    case waveform
    case xvtr
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _awaitClientIpValidation: CheckedContinuation<String, Never>?
  private var _awaitFirstStatusMessage: CheckedContinuation<Void, Error>?
  private var _awaitTcpReply: CheckedContinuation<(Int, String, String), Never>?
  private var _awaitWanValidation: CheckedContinuation<String, Never>?
  private let _broadcastCheckInterval = 10
  private let _broadcastTimeout = 30.0
  private var _firstStatusMessageReceived: Bool = false
  private var _guiClientId: String?
  private var _pinger: Pinger?
  private let _replyDictionary = ReplyDictionary()
  private let _sequencer = Sequencer()
  private var _tcp = Tcp()
  private var _timeoutTimer: DispatchSourceTimer?
  private let _udp = Udp()
  private var _wanHandle: String?
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Connect to a Radio
  /// - Parameters:
  ///   - selection: a PickerSelection instance
  ///   - isGui: true = GUI
  ///   - programName: program name
  ///   - mtuValue: max transport unit
  ///   - guiClientID: a UUID identifying the station
  ///   - lowBandwidthDax: true = use low bw DAX
  ///   - lowBandwidthConnect: true = minimize connection bandwidth
  public func connect(selection: PickerSelection,
                      isGui: Bool,
                      programName: String,
                      mtuValue: Int,
                      guiClientId: UUID,
                      lowBandwidthDax: Bool = false,
                      lowBandwidthConnect: Bool = false,
                      testDelegate: TcpProcessor? = nil) async throws {
    
    self.connectionIsGui = isGui
    self.testDelegate = testDelegate
    
    if let radio = radios.first(where: {$0.id == selection.radioId} ) {
      try _tcp.connect(radio.packet)
      Task { await ApiLog.debug("ApiModel/connect: Tcp connection established") }
      
      if selection.disconnectHandle != nil {
        // pending disconnect
        sendTcp("client disconnect \(selection.disconnectHandle!)")
      }
      
      // wait for the first Status message with my handle
      try await awaitFirstStatusMessage()
      Task { await ApiLog.debug("ApiModel/connect: First status message received") }
      
      // is this a Wan connection?
      if radio.packet.source == .smartlink {
        // YES, send Wan Connect message & wait for the reply
        _wanHandle = try await self.listenerSmartlink?.smartlinkConnect(for: radio.packet.serial, holePunchPort: radio.packet.negotiatedHolePunchPort)
        if _wanHandle == nil { throw ApiError.connection }
        Task { await ApiLog.debug("ApiModel/connect: wanHandle received") }
        
        // send Wan Validate & wait for the reply
        Task { await ApiLog.debug("ApiModel: Wan validate sent for handle=\(self._wanHandle!)") }
        let replyComponents = await sendTcpAwaitReply("wan validate handle=\(_wanHandle!)")
        //      let reply = await wanValidation()
        Task { await ApiLog.debug("ApiModel/connect: Wan validation = \(String(describing: replyComponents))") }
      }
      
      // bind UDP
      let ports = try _udp.bind(radio.packet)
      Task { await ApiLog.debug("ApiModel/connect: UDP bound, receive port <\(ports!.0)>, send port <\(ports!.1)>") }
      
      // is this a Wan connection?
      if radio.packet.source == .smartlink {
        // send Wan Register (no reply)
        sendUdp("client udp_register handle=" + connectionHandle!.hex )
        Task { await ApiLog.debug("ApiModel/connect: UDP registration sent") }
        
        // send Client Ip & wait for the reply
        let replyComponents = await sendTcpAwaitReply("client ip")
        //      sendTcp("client ip", replyHandler: ipReplyHandler)
        //      let reply = await clientIpValidation()
        Task { await ApiLog.debug("ApiModel/connect: Client ip <\(String(describing: replyComponents))>") }
      }
      
      // send the initial commands
      sendInitialCommands(isGui, programName, selection.station, mtuValue, lowBandwidthDax, lowBandwidthConnect, guiClientId)
      Task { await ApiLog.debug("ApiModel/connect: initial commands sent, isGui <\(isGui)>") }
      
      startPinging()
      Task { await ApiLog.debug("ApiModel/connect: pinging <\(radio.packet.publicIp)>") }
      
      // set the UDP port for a Local connection
      if radio.packet.source == .local {
        sendTcp("client udpport " + "\(_udp.sendPort)")
        Task { await ApiLog.debug("ApiModel/connect: Client Udp port <\(self._udp.sendPort)>") }
      }
    }
  }
  
  /// Disconnect the current Radio and remove all its objects / references
  /// - Parameter reason: an optional reason
  public func disconnect(_ reason: String? = nil) async {
    if reason == nil {
      Task { await ApiLog.debug("ApiModel/disconnect: Disconnect, \((reason == nil ? "User initiated" : reason!))") }
    }
    
    // stop any listeners
    //    _listenerLocal?.stop()
    //    _listenerLocal = nil
    //    _listenerSmartlink?.stop()
    //    _listenerSmartlink = nil
    
    _firstStatusMessageReceived = false
    
    // stop pinging (if active)
    stopPinging()
    Task { await ApiLog.debug("ApiModel/disconnect: Pinging STOPPED") }
    
    connectionHandle = nil
    
    // stop udp
    _udp.unbind()
    Task { await ApiLog.debug("ApiModel/disconnect: Disconnect, UDP unbound") }
    
    _tcp.disconnect()
    
    activeSelection = nil
    removeAllObjects()
    
    await _replyDictionary.removeAll()
    await _sequencer.reset()
    Task { await ApiLog.debug("ApiModel/disconnect: Disconnect, Objects removed") }
  }
  
  public func meterBy(shortName: Meter.ShortName, sliceId: UInt32? = nil) -> Meter? {
    
    if sliceId == nil {
      for meter in meters where meter.name == shortName.rawValue {
        return meter
      }
    } else {
      for meter in meters where sliceId! == UInt32(meter.group) && meter.name == shortName.rawValue {
        return meter
      }
    }
    return nil
  }
  
  /// Process an incoming DiscoveryPacket
  /// - Parameter packet: a received packet
  public func process(_ source: PacketSource, _ properties: KeyValuesArray, _ discoveryData: Data?) {
    
    let packet = Packet(source, properties)
    let newGuiClients = parseGuiClients(properties)
    
    let name = packet.nickname.isEmpty ? packet.model : packet.nickname
    
    // is it a Radio that has been seen previously?
    if let radio = radios.first(where: {$0.packet.id == packet.id}) {
      
      // KNOWN RADIO, has its packet changed?
      if radio.packet != packet {
        // YES, overwrite the Packet
        radio.packet = packet
        //        Task { await ApiLog.debug("ApiModel: RADIO    UPDATED Name <\(name)>, Serial <\(packet.serial)>, Source <\(packet.source == .local ? "Local" : "Smartlink")>") }
      }
      // update the TimeStamp
      radio.lastSeen = Date()
      radio.discoveryData = discoveryData
      
      for newGuiClient in newGuiClients {
        // is it already in GuiClients
        if let index = radio.guiClients.firstIndex(where: {$0.handle == newGuiClient.handle} ){
          // YES, found in GuiClients, update it as needed
          if radio.guiClients[index].station.isEmpty || radio.guiClients[index].program.isEmpty || radio.guiClients[index].ip.isEmpty || radio.guiClients[index].host.isEmpty {
            if radio.guiClients[index].station.isEmpty { radio.guiClients[index].station = newGuiClient.station }
            if radio.guiClients[index].program.isEmpty { radio.guiClients[index].program = newGuiClient.program }
            if radio.guiClients[index].ip.isEmpty { radio.guiClients[index].ip = newGuiClient.ip }
            if radio.guiClients[index].host.isEmpty { radio.guiClients[index].host = newGuiClient.host }
            let i = index
            Task { await ApiLog.debug("ApiModel/process: STATION  UPDATED Name <\(radio.guiClients[i].station)>, Radio <\(name)>, Program <\(radio.guiClients[i].program)>, Ip <\(radio.guiClients[i].ip)>, Host <\(radio.guiClients[i].host)>, Handle <\(radio.guiClients[i].handle)>, ClientId <\(radio.guiClients[i].clientId?.uuidString ?? "Unknown")>") }
          }
        } else {
          // NO, not found in GuiClients, add it
          radio.guiClients.append(newGuiClient)
          Task { await ApiLog.debug("ApiModel/process: STATION  ADDED   Name <\(newGuiClient.station)>, Radio <\(name)>, Program <\(newGuiClient.program)>, Ip <\(newGuiClient.ip)>, Host <\(newGuiClient.host)>, Handle <\(newGuiClient.handle)>, ClientId <\(newGuiClient.clientId?.uuidString ?? "Unknown")>") }
        }
      }
      // identify any missing Stations
      let toBeRemoved = Set(radio.guiClients.map(\.station)).subtracting(Set(newGuiClients.map(\.station)))
      
      // are ther any missing stations?
      guard !toBeRemoved.isEmpty else { return }
      
      // remove any missing stations
      for station in toBeRemoved {
        radio.guiClients.removeAll(where: { $0.station == station })
        Task { await ApiLog.debug("ApiModel/process: STATION REMOVED  Name <\(station)>") }
      }
      
    } else {
      // UNKNOWN radio, add it
      let radio = Radio(packet, newGuiClients, discoveryData)
      radios.append( radio )
      Task { await ApiLog.debug("ApiModel/process: RADIO    ADDED   Name <\(name)>, Serial <\(packet.serial)>, Source <\(packet.source == .local ? "Local" : "Smartlink")>, timeStamp <\(radio.lastSeen)>") }
      
      // log the GuiClients
      for guiClient in newGuiClients {
        Task { await ApiLog.debug("ApiModel/process: STATION  ADDED   Name <\(guiClient.station)>, Radio <\(name)>, Program <\(guiClient.program)>, Ip <\(guiClient.ip)>, Host <\(guiClient.host)>, Handle <\(guiClient.handle)>, ClientId <\(guiClient.clientId?.uuidString ?? "Unknown")>") }
      }
    }
    
  }
  
  /// Remove one or more Radios of a given source
  public func removeRadios(_ source: PacketSource) {
    for (i, radio) in radios.enumerated().reversed() where radio.packet.source == source {
      let name = radio.packet.nickname.isEmpty ? radio.packet.model : radio.packet.nickname
      //      for guiClient in radio.guiClients {
      //        Task { await ApiLog.debug("ApiModel: STATION  REMOVED Name <\(guiClient.station)>, Radio <\(name)>, Program <\(guiClient.program)>, Ip <\(guiClient.ip)>, Host <\(guiClient.host)>, Handle <\(guiClient.handle)>, ClientId <\(guiClient.clientId?.uuidString ?? "Unknown")>") }
      //      }
      // remove Radio
      radios.remove(at: i)
      Task { await ApiLog.debug("ApiModel/removeRadios: RADIO    REMOVED Name <\(name)>, Serial <\(radio.packet.serial)>, Source <\(radio.packet.source == .local ? "Local" : "Smartlink")>") }
    }
  }
  
  public func sendSmartlinkTest(_ serial: String) {
    listenerSmartlink?.sendSmartlinkTest(for: serial)
  }
  
  /// Send a command to the Radio (hardware) via TCP
  /// - Parameters:
  ///   - command:        a Command to be sent
  ///   - diagnostic:     use "D"iagnostic form
  ///   - replyHandler:   an optional function to handle a reply
  public func sendTcp(_ command: String, diagnostic: Bool = false, replyHandler: ReplyHandler? = nil) {
    Task {
      // assign sequenceNumber
      let sequenceNumber = await _sequencer.next()
      
      // register to be notified when reply received
      await _replyDictionary.add(sequenceNumber, ReplyEntry(command, replyHandler))
      
      // assemble the command
      let command = "C" + "\(diagnostic ? "D" : "")" + "\(sequenceNumber)|" + command
      
      // tell TCP to send it
      _tcp.send(command + "\n", sequenceNumber)
      
      // sent messages provided to the Tester (if Tester exists)
      testDelegate?.tcpProcessor(command, isInput: false)
    }
  }
  
  public func sendTcpAwaitReply(_ cmd: String, diagnostic: Bool = false) async -> (Int, String, String)  {
    // assign sequenceNumber
    let sequenceNumber = await _sequencer.next()
    //      // register to be notified when reply received
    //      await _replyDictionary.add(sequenceNumber, ReplyEntry(cmd, replyHandler))
    
    // assemble the command
    let command =  "C" + "\(diagnostic ? "D" : "")" + "\(sequenceNumber)|" + cmd
    
    // tell TCP to send it
    _tcp.send(command + "\n", sequenceNumber)
    
    // sent messages provided to the Tester (if Tester exists)
    testDelegate?.tcpProcessor(command, isInput: false)
    
    // wait for the reply
    let replyComponents = await tcpReply()
    _awaitTcpReply = nil
    
    if replyComponents.0 != sequenceNumber {
      fatalError("ApiModel/sendTcpAwaitReply: wrong reply: \(String(describing: replyComponents))")
    } else {
      Task { await ApiLog.debug("ApiModel/sendTcpAwaitReply: TCP reply = \(String(describing: replyComponents))") }
    }
    return replyComponents
  }
  
  /// Send data to the Radio (hardware) via UDP
  /// - Parameters:
  ///   - data: a Data
  public func sendUdp(_ data: Data) {
    // tell Udp to send the Data message
    _udp.send(data)
  }
  
  /// Send data to the Radio (hardware) via UDP
  /// - Parameters:
  ///   - string: a String
  public func sendUdp(_ string: String) {
    // tell Udp to send the String message
    _udp.send(string)
  }
  
  nonisolated public func tcpProcessor(_ msg: String, isInput: Bool) {
    Task { await MainActor.run {
      
      // received messages sent to the Tester
      testDelegate?.tcpProcessor(msg, isInput: true)
      
      // the first character indicates the type of message
      switch msg.prefix(1).uppercased() {
        
      case "H":  connectionHandle = String(msg.dropFirst()).handle ; Task { await ApiLog.debug("ApiModel/tcpProcessor: connectionHandle <\(self.connectionHandle?.hex ?? "missing")>") }
      case "M":  parseMessage( msg )
      case "R":  replyProcessor( msg )
      case "S":  parseStatus( msg )
      case "V":  hardwareVersion = String(msg.dropFirst())
      default:   Task { await ApiLog.warning("ApiModel/tcpProcessor: unexpected message <\(msg)>") }
      }
    }}
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  private func bind(_ station: String, _ clientId: String) {
    boundClientId = clientId
    sendTcp("client bind client_id=\(clientId)")
    Task { await ApiLog.info("ApiModel/bind: NonGui bound to <\(station)>, Client ID <\(clientId)>") }
  }
  
  public func commandsReplyHandler(_ command: String, _ reply: String) {
    var keyValues: KeyValuesArray
    
    // separate it into its components
    let components = reply.components(separatedBy: "|")
    // ignore incorrectly formatted replies
    if components.count < 2 {
      Task { await ApiLog.warning("ApiModel/commandsReplyHandler: incomplete reply, <r\(reply)>") }
      return
    }
    if components[1] != kNoError {
      Task { await ApiLog.warning("ApiModel/commandsReplyHandler: non-zero reply for command <\(command)>, <\(reply)>") }
      return
    }
    
    // get any additional data
    if components.count > 2 {
      let additionalData = components[2]
      
      // process replies to the internal "sendCommands"?
      switch command {
      case "radio uptime":  keyValues = "uptime=\(additionalData)".keyValuesArray()
      case "version":       keyValues = additionalData.keyValuesArray(delimiter: "#")
      case "ant list":      keyValues = "ant_list=\(additionalData)".keyValuesArray()
      case "mic list":      keyValues = "mic_list=\(additionalData)".keyValuesArray()
      case "info":          keyValues = additionalData.keyValuesArray(delimiter: ",")
      default: return
      }
      if let radio = radios.first(where: {$0.id == activeSelection!.radioId }) {
        radio.parse(keyValues)
      }
    }
  }
  
  private func onFirstStatusMessageReceived() {
    if let continuation = _awaitFirstStatusMessage {
      _awaitFirstStatusMessage = nil
      continuation.resume()
    }
  }
  
  private func parse(_ statusType: String, _ statusMessage: String, _ connectionHandle: UInt32?) {
    
    // Check for unknown Object Types
    guard let objectType = ObjectType(rawValue: statusType)  else {
      // log it and ignore the message
      Task { await ApiLog.warning("ApiModel/parse: unknown status token = \(statusType)") }
      return
    }
    
    switch objectType {
    case .amplifier:            Amplifier.status(self, statusMessage.keyValuesArray(), !statusMessage.contains(kRemoved))
    case .atu:                  atu.parse(Array(statusMessage.keyValuesArray() ))
    case .bandSetting:          BandSetting.status(self, Array(statusMessage.keyValuesArray().dropFirst(1) ), !statusMessage.contains(kRemoved))
    case .client:               preProcessClient(statusMessage.keyValuesArray(), !statusMessage.contains(kDisconnected), connectionHandle)
    case .cwx:                  cwx.parse(Array(statusMessage.keyValuesArray().dropFirst(1) ))
    case .display:              preProcessDisplay(statusMessage)
    case .equalizer:            Equalizer.status(self, statusMessage.keyValuesArray(), !statusMessage.contains(kRemoved))
    case .gps:                  gps.parse(Array(statusMessage.keyValuesArray(delimiter: "#").dropFirst(1)) )
    case .interlock:            preProcessInterlock(statusMessage)
    case .memory:               Memory.status(self, statusMessage.keyValuesArray(), !statusMessage.contains(kRemoved))
    case .meter:                Meter.status(self, statusMessage.keyValuesArray(delimiter: "#"), !statusMessage.contains(kRemoved))
    case .profile:              Profile.status(self, statusMessage.keyValuesArray(delimiter: "="), !statusMessage.contains(kNotInUse))
    case .radio:                Radio.status(self, statusMessage.keyValuesArray(), !statusMessage.contains(kNotInUse))
    case .slice:                Slice.status(self, statusMessage.keyValuesArray(), !statusMessage.contains(kNotInUse))
    case .stream:               preProcessStream(statusMessage, connectionHandle)
    case .tnf:                  Tnf.status(self, statusMessage.keyValuesArray(), !statusMessage.contains(kRemoved))
    case .transmit:             preProcessTransmit(statusMessage)
    case .usbCable:             UsbCable.status(self, statusMessage.keyValuesArray(), !statusMessage.contains(kRemoved))
    case .wan:                  wan.parse(Array(statusMessage.keyValuesArray()) )
    case .waveform:             waveform.parse(Array(statusMessage.keyValuesArray(delimiter: "=").dropFirst(1)) )
    case .xvtr:                 Xvtr.status(self, statusMessage.keyValuesArray(), !statusMessage.contains(kNotInUse))
      
    case .panadapter, .waterfall: break                                                   // handled by "display"
    }
  }
  
  /// Parse a client connect status message
  /// - Parameters:
  ///   - properties: message properties as a KeyValuesArray
  ///   - handle: the radio's connection handle
  private func parseConnection(properties: KeyValuesArray, handle: UInt32, connectionHandle: UInt32?) {
    var clientId = ""
    var program = ""
    var station = ""
    var pttEnabled = false
    
    enum Property: String {
      case clientId = "client_id"
      case pttEnabled = "local_ptt"
      case program
      case station
    }
    
    // if handle is mine, this client is fully initialized
    clientInitialized = ( handle == connectionHandle )
    
    // parse remaining properties
    for property in properties.dropFirst(2) {
      
      // check for unknown properties
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore this Key
        Task { await ApiLog.warning("ApiModel/parseConnection: unknown client property, \(property.key)=\(property.value)") }
        continue
      }
      // Known properties, in alphabetical order
      switch token {
        
      case .clientId:         clientId = property.value
      case .pttEnabled:       pttEnabled = property.value.bValue
      case .program:          program = property.value.trimmingCharacters(in: .whitespaces)
      case .station:          station = property.value.replacingOccurrences(of: "\u{007f}", with: "").trimmingCharacters(in: .whitespaces)
      }
    }
    
    if let radio = radios.first(where: {$0.id == activeSelection?.radioId}) {
      if let index = radio.guiClients.firstIndex(where: { $0.handle == handle.hex }) {
        radio.guiClients[index].clientId = UUID(uuidString: clientId)!
        radio.guiClients[index].program = program
        radio.guiClients[index].station = station
        radio.guiClients[index].pttEnabled = pttEnabled
        let ip = radio.guiClients[index].ip
        let host = radio.guiClients[index].host
        Task { await ApiLog.debug("ApiModel/parseConnection: STATION  UPDATED Name <\(station)>, Radio <\(radio.packet.nickname)> Program <\(program)>, Ip <\(ip)>, Host <\(host)>, Handle <\(handle.hex)>, ClientId <\(UUID(uuidString: clientId)!)>") }
        
        // if needed, bind to the Station
        if connectionIsGui == false && station == activeSelection?.station && boundClientId == nil {
          bind(station, clientId)
        }
        
      } else {
        radio.guiClients.append( GuiClient(handle: handle.hex, station: station, program: program, clientId: UUID(uuidString: clientId), pttEnabled: pttEnabled) )
        Task { await ApiLog.debug("ApiModel/parseConnection: STATION  ADDED   Name <\(station)>, Radio <\(radio.packet.nickname)>, Program <\(program)>, Handle <\(handle.hex)>, Client Id <\(UUID(uuidString: clientId)!)>") }
        
        // if needed, bind to the Station
        if connectionIsGui == false && station == activeSelection?.station && boundClientId == nil {
          bind(station, clientId)
        }
      }
    }
  }
  
  
  
  //    if let radio = radios.first(where: {$0.guiClients.contains   }) {
  //      if handle == connectionHandle {
  //        if var guiClient = radio.guiClients.first(where: {handle.hex == $0.handle} ) {
  //          radio.guiClients.remove(guiClient)
  //          guiClient.clientId = UUID(uuidString: clientId)!
  //          if !program.isEmpty { guiClient.program = program }
  //          if !station.isEmpty { guiClient.station = station }
  //          radio.guiClients.insert(guiClient)
  //          Task { await ApiLog.debug("ApiModel: STATION  UPDATED Name <\(station)>, Program <\(program)>, Handle <\(handle.hex)>, ClientId <\(UUID(uuidString: clientId)!)> on RADIO <\(radio.packet.nickname)> ") }
  //
  //          // if needed, bind to the Station
  //          if connectionIsGui == false && station == activeStation {
  //            bind(clientId)
  //          }
  //
  //        } else {
  //          radio.guiClients.insert(GuiClient(handle: handle.hex, station: station, program: program, clientId: UUID(uuidString: clientId)))
  //          Task { await ApiLog.debug("ApiModel: STATION  ADDED   Name <\(station)>, Program <\(program)>, Handle <\(handle.hex)>, Client Id <\(UUID(uuidString: clientId)!)> on RADIO <\(radio.packet.nickname)>") }
  //
  //          // if needed, bind to the Station
  //          if connectionIsGui == false && station == activeStation {
  //            bind(clientId)
  //          }
  //        }
  //      }
  
  /// Parse a client disconnect status message
  /// - Parameters:
  ///   - properties: message properties as a KeyValuesArray
  ///   - handle: the radio's connection handle
  private func parseDisconnection(properties: KeyValuesArray, handle: UInt32, connectionHandle: UInt32?) {
    var reason = ""
    
    enum Property: String {
      case duplicateClientId        = "duplicate_client_id"
      case forced
      case wanValidationFailed      = "wan_validation_failed"
    }
    
    // is it me?
    if handle == connectionHandle {
      // YES, parse remaining properties
      for property in properties.dropFirst(2) {
        // check for unknown property
        guard let token = Property(rawValue: property.key) else {
          // log it and ignore this Key
          Task { await ApiLog.warning("ApiModel/parseDisconnection: unknown client disconnection property, \(property.key)=\(property.value)") }
          continue
        }
        // Known properties, in alphabetical order
        switch token {
          
        case .duplicateClientId:    if property.value.bValue { reason = "Duplicate ClientId" }
        case .forced:               if property.value.bValue { reason = "Forced" }
        case .wanValidationFailed:  if property.value.bValue { reason = "Wan validation failed" }
        }
      }
      Task { await ApiLog.warning("ApiModel/parseDisconnection: client disconnection, reason = \(reason)") }
      
      clientInitialized = false
      
    }
    //    else {
    //      // is it a know GuiClient?
    //      if let index = guiClients.firstIndex(where: {$0.handle == handle.hex}) {
    //        // YES, remove and log it
    //        let removed = guiClients[index]
    //        guiClients.remove(at: index)
    //        Task { await ApiLog.debug("ApiModel: STATION  REMOVED Name <\(removed.station)>, Program <\(removed.program)>, Ip <\(removed.ip)>, Host <\(removed.host)>, Handle <\(removed.handle)>, ClientId <\(removed.clientId?.uuidString ?? "Unknown")>") }
    //      }
    //    }
  }
  
  private func parseGuiClients(_ properties: KeyValuesArray) -> [GuiClient] {
    var guiClients = [GuiClient]()
    var handles = [String]()
    var hosts = [String]()
    var ips = [String]()
    var programs = [String]()
    var stations = [String]()
    
    enum Property: String {
      case guiClientHandles           = "gui_client_handles"
      case guiClientHosts             = "gui_client_hosts"
      case guiClientIps               = "gui_client_ips"
      case guiClientPrograms          = "gui_client_programs"
      case guiClientStations          = "gui_client_stations"
    }
    
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      switch Property(rawValue: property.key) {
        
      case .guiClientHandles:           handles = property.value.replacingOccurrences(of: "\u{7F}", with: "").valuesArray(delimiter: ",")
      case .guiClientHosts:             hosts = property.value.replacingOccurrences(of: "\u{7F}", with: "").valuesArray(delimiter: ",")
      case .guiClientIps:               ips = property.value.replacingOccurrences(of: "\u{7F}", with: "").valuesArray(delimiter: ",")
      case .guiClientPrograms:          programs = property.value.replacingOccurrences(of: "\u{7F}", with: "").valuesArray(delimiter: ",")
      case .guiClientStations:          stations = property.value.replacingOccurrences(of: "\u{7F}", with: "").valuesArray(delimiter: ",")
      default:                          break
      }
    }
    // all three must be populated
    if (programs.isEmpty || stations.isEmpty || handles.isEmpty || ips.isEmpty || hosts.isEmpty) == false {
      // must be an equal number of entries in each
      if programs.count == stations.count && programs.count == handles.count && programs.count == ips.count && programs.count == hosts.count {
        for (i, handle) in handles.enumerated() {
          guiClients.append( GuiClient( handle: handle, station: stations[i], program: programs[i], ip: ips[i], host: hosts[i] ) )
        }
      }
    }
    return guiClients
  }
  
  /// Parse a Message.
  /// - Parameters:
  ///   - commandSuffix:      a Command Suffix
  private func parseMessage(_ msg: String) {
    // separate it into its components
    let components = msg.dropFirst().components(separatedBy: "|")
    
    // ignore incorrectly formatted messages
    if components.count < 2 {
      Task { await ApiLog.warning("ApiModel/parseMessage: incomplete message = c\(msg)") }
      return
    }
    
    // log it
    FlexError.logError(errorCode: components[0], msgText:  components[1])
    
    // FIXME: Take action on some/all errors?
  }
  
  /// Parse a Status
  /// - Parameters:
  ///   - commandSuffix:      a Command Suffix
  private func parseStatus(_ commandSuffix: String) {
    
    // separate it into its components ( [0] = <apiHandle>, [1] = <remainder> )
    let components = commandSuffix.dropFirst().components(separatedBy: "|")
    
    // ignore incorrectly formatted status
    guard components.count > 1 else {
      Task { await ApiLog.warning("ApiModel/parseStatus: incomplete status = c\(commandSuffix)") }
      return
    }
    
    // find the space & get the msgType
    let spaceIndex = components[1].firstIndex(of: " ")!
    let statusType = String(components[1][..<spaceIndex])
    
    // everything past the msgType is in the remainder
    let messageIndex = components[1].index(after: spaceIndex)
    let statusMessage = String(components[1][messageIndex...])
    
    // is this status message the first for our handle?
    if _firstStatusMessageReceived == false && components[0].handle == connectionHandle {
      // YES, set the API state to finish the UDP initialization
      _firstStatusMessageReceived = true
      onFirstStatusMessageReceived()
    }
    
    parse(statusType, statusMessage, self.connectionHandle)
  }
  
  private func removeAll(of type: ObjectType) {
    switch type {
    case .amplifier:            amplifiers.removeAll()
    case .bandSetting:          bandSettings.removeAll()
    case .equalizer:            equalizers.removeAll()
    case .memory:               memories.removeAll()
    case .meter:                meters.removeAll()
    case .panadapter:           panadapters.removeAll()
    case .profile:              profiles.removeAll()
    case .slice:                slices.removeAll()
    case .tnf:                  tnfs.removeAll()
    case .usbCable:             usbCables.removeAll()
    case .waterfall:            waterfalls.removeAll()
    case .xvtr:                 xvtrs.removeAll()
    default:            break
    }
  }
  
  /// Remove all Radio objects
  private func removeAllObjects() {
    removeAll(of: .amplifier)
    removeAll(of: .bandSetting)
    removeAll(of: .equalizer)
    removeAll(of: .memory)
    removeAll(of: .meter)
    removeAll(of: .panadapter)
    removeAll(of: .profile)
    removeAll(of: .slice)
    removeAll(of: .tnf)
    removeAll(of: .usbCable)
    removeAll(of: .waterfall)
    removeAll(of: .xvtr)
    Task { await ApiLog.debug("ApiModel/removeAll: removed all objects") }
  }
  
  private func replyHandlerIp(_ command: String, _ reply: String) {
    // YES, resume it
    _awaitClientIpValidation?.resume(returning: reply)
  }
  
  private func replyHandlerWanValidation(_ command: String, _ reply: String) {
    // YES, resume it
    _awaitWanValidation?.resume(returning: reply)
  }
  
  private func replyParser(_ replyMessage: String) -> (Int, String, String)? {
    // separate it into its components
    let components = replyMessage.dropFirst().components(separatedBy: "|")
    // ignore incorrectly formatted replies
    if components.count < 2 {
      Task { await ApiLog.warning("ApiModel/replyParser: incomplete reply, R\(replyMessage)") }
      return nil
    }
    // get the sequence number, reply and any additional data
    let sequenceNumber = components[0].sequenceNumber
    let replyValue = components[1]
    let suffix = components.count < 3 ? "" : components[2]
    return (sequenceNumber, replyValue, suffix)
  }
  
  /// Parse Replies
  /// - Parameters:
  ///   - commandSuffix:      a Reply Suffix
  private func replyProcessor(_ replyMessage: String) {
    
    // separate it into its components
    if let components = replyParser(replyMessage) {
      // are we waiting for this reply?
      if _awaitTcpReply != nil {
        // YES, resume
        Task { await ApiLog.debug( "ApiModel/replyProcessor: resuming tcpReply" ) }
        _awaitTcpReply!.resume(returning: components)
        
      } else {
        
        Task {
          var keyValues = KeyValuesArray()
          
          let sequenceNumber = components.0
          let replyValue = components.1
          let suffix = components.2
          
          // is there a ReplyEntry for the sequence number (in the ReplyDictionary)?
          if let replyEntry = await _replyDictionary[ sequenceNumber ] {
            
            // YES, remove that entry in the ReplyDictionary
            await _replyDictionary.remove(sequenceNumber)
            
            // Anything other than kNoError is an error, log it
            // ignore non-zero reply from "client program" command
            if replyValue != kNoError {
              if replyEntry.command.hasPrefix("client program ") {
                Task { await ApiLog.info("FlexMsg: command <\(replyEntry.command)>, code <\(replyValue)>, message <\(FlexError.description(replyValue))>") }
              } else {
                Task { await ApiLog.error("ApiModel/replyProcessor: command <\(replyEntry.command)>, replyValue <\(replyValue)>, description <\(FlexError.description(replyValue))>") }
              }
            }
            
            if replyEntry.replyHandler == nil {
              
              // process replies to the internal "sendCommands"?
              switch replyEntry.command {
              case "radio uptime":  keyValues = "uptime=\(suffix)".keyValuesArray()
              case "version":       keyValues = suffix.keyValuesArray(delimiter: "#")
              case "ant list":      keyValues = "ant_list=\(suffix)".keyValuesArray()
              case "mic list":      keyValues = "mic_list=\(suffix)".keyValuesArray()
              case "info":          keyValues = suffix.keyValuesArray(delimiter: ",")
              case "ping":          updatePingInterval(replyEntry.timeStamp)
              default: return
              }
              
              if let activeSelection, let radio = radios.first(where: {$0.id == activeSelection.radioId }) {
                radio.parse(keyValues)
              }
              
            } else {
              // call the sender's Handler
              replyEntry.replyHandler?(replyEntry.command, replyMessage)
            }
          } else {
            // no reply entry for this sequence number
            Task { await ApiLog.error("ApiModel/replyProcessor: sequenceNumber \(sequenceNumber) not found in the ReplyDictionary") }
          }
        }
      }
    }
  }
  
  private func updatePingInterval(_ timeStamp: Date) {
    let now = Date()
    pingIntervals[pingIntervalIndex] = now.timeIntervalSince(timeStamp)
    pingIntervalIndex = (pingIntervalIndex + 1) % pingIntervals.count
  }
  
  private func sendInitialCommands(_ isGui: Bool,
                                   _ programName: String,
                                   _ stationName: String,
                                   _ mtuValue: Int,
                                   _ lowBandwidthDax: Bool,
                                   _ lowBandwidthConnect: Bool,
                                   _ guiClientId: UUID) {
    
    if isGui { sendTcp("client gui \(guiClientId.uuidString)") }
    sendTcp("client program " + programName)
    if isGui { sendTcp("client station \(stationName)") }
    if lowBandwidthConnect { lowBandwidthConnectRequest() }
    infoRequest()
    versionRequest()
    requestAntennaList()
    micListRequest()
    globalProfileRequest()
    txProfileRequest()
    micProfileRequest()
    displayProfileRequest()
    sendSubciptions()
    setMtuLimit(mtuValue)
    setLowBandwidthDax(lowBandwidthDax)
    uptimeRequest()
  }
  
  private func sendSubciptions(replyHandler: ReplyHandler? = nil) {
    sendTcp("sub tx all")
    sendTcp("sub atu all")
    sendTcp("sub amplifier all")
    sendTcp("sub meter all")
    sendTcp("sub pan all")
    sendTcp("sub slice all")
    sendTcp("sub gps all")
    sendTcp("sub audio_stream all")
    sendTcp("sub cwx all")
    sendTcp("sub xvtr all")
    sendTcp("sub memories all")
    sendTcp("sub daxiq all")
    sendTcp("sub dax all")
    sendTcp("sub usb_cable all")
    sendTcp("sub tnf all")
    sendTcp("sub client all")
    //      send("sub spot all")    // TODO:
  }
  
  private func startPinging() {
    // tell the Radio to expect pings
    sendTcp("keepalive enable")
    // start pinging the Radio
    _pinger = Pinger(self)
  }
  
  private func stopPinging() {
    _pinger = nil
  }
  
  private func timeoutStart() {
    // Create the timer’s dispatch source
    _timeoutTimer = DispatchSource.makeTimerSource()
    
    // Setup the timer
    _timeoutTimer!.schedule(deadline: .now(), repeating: .seconds(_broadcastCheckInterval))
    
    // Set the event handler
    _timeoutTimer!.setEventHandler  { [weak self] in
      guard let self = self else { return }
      
      Task { await MainActor.run {
        for (i, radio) in self.radios.enumerated().reversed() {
          if radio.packet.source == .local {
            let interval = Date().timeIntervalSince(radio.lastSeen)
            self.radios[i].intervals[self.radios[i].intervalIndex] = interval
            
            self.radios[i].intervalIndex = (self.radios[i].intervalIndex + 1) % self.radios[i].intervals.count
            
            if interval > self._broadcastTimeout {
              let name = radio.packet.nickname.isEmpty ? radio.packet.model : radio.packet.nickname
              //              for guiClient in radio.guiClients {
              //                Task { await ApiLog.debug("ApiModel: STATION  REMOVED Name <\(guiClient.station)>, Radio <\(name)>, Program <\(guiClient.program)>, Ip <\(guiClient.ip)>, Host <\(guiClient.host)>, Handle <\(guiClient.handle)>, ClientId <\(guiClient.clientId?.uuidString ?? "Unknown")>") }
              //              }
              
              // remove Radio
              self.radios.remove(at: i)
              Task { await ApiLog.debug("ApiModel/timeoutStart: RADIO    REMOVED Name <\(name)>, Serial <\(radio.packet.serial)>, Source <\(radio.packet.source == .local ? "Local" : "Smartlink")>, timeout (\(interval) seconds)") }
            }
          }
        }
      }}
    }
    
    // Start the timer
    _timeoutTimer!.resume()
  }
  
  func timeoutStop() {
    _timeoutTimer?.cancel()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Pre-Process methods
  
  private func preProcessClient(_ properties: KeyValuesArray, _ inUse: Bool = true, _ connectionHandle: UInt32?) {
    // is there a valid handle"
    if let handle = properties[0].key.handle {
      switch properties[1].key {
        
      case kConnected:       parseConnection(properties: properties, handle: handle, connectionHandle: connectionHandle)
      case kDisconnected:    parseDisconnection(properties: properties, handle: handle, connectionHandle: connectionHandle)
      default:                      break
      }
    }
  }
  
  private func preProcessDisplay(_ statusMessage: String) {
    let properties = statusMessage.keyValuesArray()
    // Waterfall or Panadapter?
    switch properties[0].key {
    case ObjectType.panadapter.rawValue:  Panadapter.status(self, Array(statusMessage.keyValuesArray().dropFirst()), !statusMessage.contains(kRemoved) )
    case ObjectType.waterfall.rawValue:   Waterfall.status(self, Array(statusMessage.keyValuesArray().dropFirst()), !statusMessage.contains(kRemoved) )
    default: break
    }
  }
  
  private func preProcessInterlock(_ statusMessage: String) {
    let properties = statusMessage.keyValuesArray()
    // Band Setting or Interlock?
    switch properties[0].key {
    case ObjectType.bandSetting.rawValue:   BandSetting.status(self, Array(statusMessage.keyValuesArray().dropFirst()), !statusMessage.contains(kRemoved) )
    default:                                interlock.parse(properties) ; interlockStateChange(interlock.state)
    }
  }
  
  public func preProcessStream(_ statusMessage: String, _ connectionHandle: UInt32?) {
    let properties = statusMessage.keyValuesArray()
    
    // is the 1st KeyValue a StreamId?
    if let id = properties[0].key.streamId {
      
      // is it a removal?
      if statusMessage.contains(kRemoved) {
        // YES
        removeStream(having: id)
        
      } else {
        // NO is it for me?
        if isForThisClient(properties, connectionHandle) {
          // YES
          guard properties.count > 1 else {
            Task { await ApiLog.warning("ApiModel/preProcessStream: invalid Stream message: \(statusMessage)") }
            return
          }
          guard let token = StreamType(rawValue: properties[1].value) else {
            // log it and ignore the Key
            Task { await ApiLog.warning("ApiModel/preProcessStream: unknown Stream type: \(properties[1].value)") }
            return
          }
          switch token {
            
          case .daxIqStream:          DaxIq.status(self, properties)
          case .daxMicAudioStream:    DaxMicAudio.status(self, properties)
          case .daxRxAudioStream:     DaxRxAudio.status(self, properties)
          case .daxTxAudioStream:     DaxTxAudio.status(self, properties)
          case .remoteRxAudioStream:  RemoteRxAudio.status(self, properties)
          case .remoteTxAudioStream:  RemoteTxAudio.status(self, properties)
            
          case .panadapter, .waterfall: break     // should never be seen here
          }
        }
      }
    } else {
      Task { await ApiLog.warning("ApiModel/preProcessStream: invalid Stream message: \(statusMessage)") }
    }
  }
  
  private func preProcessTransmit(_ statusMessage: String) {
    let properties = statusMessage.keyValuesArray()
    // Band Setting or Transmit?
    switch properties[0].key {
    case ObjectType.bandSetting.rawValue:   BandSetting.status(self, Array(statusMessage.keyValuesArray().dropFirst(1) ), !statusMessage.contains(kRemoved))
    default:                                transmit.parse( Array(properties.dropFirst() ))
    }
  }
  
  /// Change the MOX property when an Interlock state change occurs
  /// - Parameter state:            a new Interloack state
  private func interlockStateChange(_ state: String) {
    if let radio = radios.first(where: { $0.id == activeSelection?.radioId }) {
      let currentMox = radio.mox
      
      // if PTT_REQUESTED or TRANSMITTING
      if state == Interlock.States.pttRequested.rawValue || state == Interlock.States.transmitting.rawValue {
        // and mox not on, turn it on
        if currentMox == false { radio.mox = true }
        
        // if READY or UNKEY_REQUESTED
      } else if state == Interlock.States.ready.rawValue || state == Interlock.States.unKeyRequested.rawValue {
        // and mox is on, turn it off
        if currentMox == true { radio.mox = false  }
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private continuation methods
  
  //  private func awaitFirstStatusMessage() async {
  //    return await withCheckedContinuation{ continuation in
  //      _awaitFirstStatusMessage = continuation
  //      Task { await ApiLog.debug("ApiModel: waiting for first status message") }
  //    }
  //  }
  
  private func awaitFirstStatusMessage(timeout: Int = 5) async throws {
    try await withCheckedThrowingContinuation { continuation in
      Task { @MainActor in
        _awaitFirstStatusMessage = continuation
        await ApiLog.debug("ApiModel/awaitFirstStatusMessage: waiting for first status message")
        
        Task {
          try await Task.sleep(for: .seconds(timeout))
          await MainActor.run {
            if let continuation = _awaitFirstStatusMessage {
              _awaitFirstStatusMessage = nil
              continuation.resume(throwing: NSError(
                domain: "ApiModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for first status message"]
              ))
            }
          }
        }
      }
    }
  }
      
  private func clientIpValidation() async -> (String) {
    return await withCheckedContinuation{ continuation in
      _awaitClientIpValidation = continuation
      Task { await ApiLog.debug("ApiModel/clientIpValidation: Client ip request sent") }
    }
  }
  
  private func wanValidation() async -> (String) {
    return await withCheckedContinuation{ continuation in
      _awaitWanValidation = continuation
      Task { await ApiLog.debug("ApiModel/wanValidation: Wan validate sent for handle=\(self._wanHandle!)") }
    }
  }
  
  private func tcpReply() async -> (Int, String, String) {
    return await withCheckedContinuation{ continuation in
      _awaitTcpReply = continuation
      Task { await ApiLog.debug("ApiModel/tcpReply: awaiting a TCP reply") }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Stream methods
  
  private func removeStream(having id: UInt32) {
    if daxIqs[id] != nil {
      daxIqs[id] = nil
      Task { await ApiLog.debug("ApiModel/removeStream: DaxIq \(id.hex): REMOVED") }
    }
    else if daxMicAudio?.id == id {
      daxMicAudio = nil
      Task { await ApiLog.debug("ApiModel/removeStream: DaxMicAudio \(id.hex): REMOVED") }
    }
    else if daxRxAudios[id] != nil {
      daxRxAudios[id] = nil
      Task { await ApiLog.debug("ApiModel/removeStream: DaxRxAudio \(id.hex): REMOVED") }
      
    } else if daxTxAudio?.id == id {
      daxTxAudio = nil
      Task { await ApiLog.debug("ApiModel/removeStream: DaxTxAudio \(id.hex): REMOVED") }
    }
    else if remoteRxAudio?.id == id {
      remoteRxAudio = nil
      Task { await ApiLog.debug("ApiModel/removeStream: RemoteRxAudio \(id.hex): REMOVED") }
    }
    else if remoteTxAudio?.id == id {
      remoteTxAudio = nil
      Task { await ApiLog.debug("ApiModel/removeStream: RemoteTxAudio \(id.hex): REMOVED") }
    }
  }
  
  /// Determine if status is for this client
  /// - Parameters:
  ///   - properties:     a KeyValuesArray
  ///   - clientHandle:   the handle of ???
  /// - Returns:          true if a mtch
  private func isForThisClient(_ properties: KeyValuesArray, _ connectionHandle: UInt32?) -> Bool {
    var clientHandle : UInt32 = 0
    
    guard testDelegate != nil else { return true }
    
    if let connectionHandle {
      // find the handle property
      for property in properties.dropFirst(2) where property.key == "client_handle" {
        clientHandle = property.value.handle ?? 0
      }
      return clientHandle == connectionHandle
    }
    return false
  }
}
