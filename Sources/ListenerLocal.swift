//
//  LocalListener.swift
//  FlexApiFeature/Listener
//
//  Created by Douglas Adams on 10/28/21
//  Copyright © 2021 Douglas Adams. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

//import SharedFeature
//import VitaFeature


public enum LanListenerError: Error {
  case kSocketError
  case kReceivingError
}

/// Listener implementation
///
///      listens for the udp broadcasts of a Flex-6000 Radio
///
@MainActor
public final class ListenerLocal: NSObject, ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  nonisolated private let _objectModel: ObjectModel

  private var _checkTimer: DispatchSourceTimer?
  private let _formatter = DateFormatter()
  private var _ignoreTimeStamps = true
  private var _lastBroadcastTime = Date()
  private var _logBroadcasts = false
  private let _timerQ = DispatchQueue(label: "ListenerLocal" + ".timerQ", attributes: .concurrent)
  private let _udpQ = DispatchQueue(label: "ListenerLocal" + ".udpQ")
  private var _udpSocket: GCDAsyncUdpSocket!
  
  
  var currentBytes = [UInt8](repeating: 0x00, count: 560)
  var previousBytes = [UInt8](repeating: 0x00, count: 560)
  
  var currentPayload: String = ""
  var previousPayload: String = ""
  
  var currentNullCount = 0
  
//  static let broadcastTimeout = 20.0
    
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  init(_ objectModel: ObjectModel, port: UInt16 = 4992, logBroadcasts: Bool = false, ignoreTimeStamps: Bool = false) {
    _objectModel = objectModel
    _logBroadcasts = logBroadcasts
    _ignoreTimeStamps = ignoreTimeStamps
    super.init()
    
    _formatter.timeZone = .current
    _formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    
    // create a Udp socket and set options
    _udpSocket = GCDAsyncUdpSocket( delegate: self, delegateQueue: _udpQ )
    _udpSocket.setPreferIPv4()
    _udpSocket.setIPv6Enabled(false)
    
    try! _udpSocket.enableReusePort(true)
    try! _udpSocket.bind(toPort: port)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  func start(checkInterval: Int = 1, timeout: TimeInterval = 20.0) {
      do {
          try _udpSocket.beginReceiving()
          log.info("Local Listener: STARTED")
      } catch {
          log.error("Error starting UDP socket: \(error)")
          return
      }
      
      // Create the timer’s dispatch source
    _checkTimer = DispatchSource.makeTimerSource(queue: _timerQ)
      
      // Setup the timer
      _checkTimer?.schedule(deadline: .now(), repeating: .seconds(checkInterval))
      
      // Set the event handler
    _checkTimer?.setEventHandler  { [weak self] in
      guard let self = self else { return }
      
      Task { await MainActor.run {
        self._objectModel.removeLostRadios(Date(), timeout)
      }}
      }

      // Start the timer
      _checkTimer?.resume()
  }

  /// stop the listener
  func stop() {
    _checkTimer?.cancel()
    _checkTimer = nil
    _udpSocket?.close()
    log.info("Local Listener: STOPPED")
  }
}

//private var timer: DispatchSourceTimer?
//
//func startTimer() {
//    let queue = DispatchQueue(label: "com.example.timer", attributes: .concurrent)
//    timer = DispatchSource.makeTimerSource(queue: queue)
//    
//    timer?.schedule(deadline: .now(), repeating: .seconds(1))
//    
//    timer?.setEventHandler {
//        print("Timer fired at \(Date())")
//    }
//    
//    timer?.resume()
//}
//
//func stopTimer() {
//  timer?.cancel()
//  timer = nil
//}

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
  nonisolated public func udpSocket(_ sock: GCDAsyncUdpSocket,
                                    didReceive data: Data,
                                    fromAddress address: Data,
                                    withFilterContext filterContext: Any?) {
    
    //    checkBroadcastBytes(data, address)
    
    // is it a VITA packet?
    guard let vita = Vita.decode(from: data) else { return }
    
    // YES, is it a Discovery Packet?
    if vita.classIdPresent && vita.classCode == .discovery {
      // Payload is a series of strings of the form <key=value> separated by ' ' (space)
      let payloadData = NSString(bytes: vita.payloadData, length: vita.payloadSize, encoding: String.Encoding.utf8.rawValue)! as String
      let properties = payloadData.trimmingCharacters(in: CharacterSet(charactersIn: "\0")).keyValuesArray()
      // eliminate any Nulls at the end of the payload & form KeyValuesArray
      let packet = Packet(.local, properties)
      let guiClients = parseClientData(properties)
      
      // YES, process it
      Task { await self._objectModel.process(packet, guiClients, data) }
    }
  }
  
  nonisolated private func parseClientData(_ properties: KeyValuesArray) -> [GuiClient] {
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
}


extension  ListenerLocal {
  // ----------------------------------------------------------------------------
  // MARK: - Debugging tools extension
  
  public func checkBroadcastBytes(_ data: Data, _ address: Data) {
    (data as NSData).getBytes(&currentBytes, range: NSMakeRange(0, 551))
    
    if _ignoreTimeStamps {
      currentBytes[1] = UInt8(0)
      currentBytes[16] = UInt8(0)
      currentBytes[17] = UInt8(0)
      currentBytes[18] = UInt8(0)
      currentBytes[19] = UInt8(0)
      currentBytes[20] = UInt8(0)
      currentBytes[21] = UInt8(0)
      currentBytes[22] = UInt8(0)
      currentBytes[23] = UInt8(0)
      currentBytes[24] = UInt8(0)
      currentBytes[25] = UInt8(0)
      currentBytes[26] = UInt8(0)
      currentBytes[27] = UInt8(0)
    }
    
    //      var addressString = ""
    //      (address as NSData).getBytes(&addressString, range: NSMakeRange(0, 199))
    //      print("Address = \(addressString)")
    
    if currentBytes.count == previousBytes.count {
      if currentBytes != previousBytes {
        print(hexDump(data))
      }
    } else {
      print(hexDump(data))
    }
    previousBytes = currentBytes
  }
  
  public func checkPayload(_ payloadData: String) {
    currentPayload = payloadData
    if currentPayload != previousPayload {
      print("payload = \(payloadData)")
      previousPayload = currentPayload
    }
  }
  
  public func checkPayloadNulls(_ payloadData: String) {
    currentNullCount = previousPayload.count - payloadData.count
    if currentNullCount > 0 {
      print("\(currentNullCount) nulls removed from Payload")
    }
  }
  
  /// Create a String representing a Hex Dump of a UInt8 array
  ///
  /// - Parameters:
  ///   - data:           an array of UInt8
  ///   - len:            the number of elements to be processed
  /// - Returns:          a String
  ///
  public func hexDump(rawData: Data, address: Data, count: Int, data: [UInt8], len: Int) -> String {
    
    print("\nAddress: \(address as NSData))")
    print("Data:    \(rawData as NSData))\n")
    
    var string = "  \(String(format: "%3d", count))    00 01 02 03 04 05 06 07   08 09 0A 0B 0C 0D 0E 0F\n"
    string += " bytes    -------------------------------------------------\n\n"
    
    var address = 0
    string += address.toHex() + "   "
    for i in 1...len {
      string += String(format: "%02X", data[i-1]) + " "
      if (i % 8) == 0 { string += "  " }
      if (i % 16) == 0 {
        string += "\n"
        address += 16
        string += address.toHex() + "   "
      }
    }
    string += "\n         -------------------------------------------------\n\n"
    return string
  }
  
  
  
  public func hexDump(_ data: Data) -> String {
    let len = 552
    var bytes = [UInt8](repeating: 0x00, count: len)

    (data as NSData).getBytes(&bytes, range: NSMakeRange(0, len))
    
    var string = "  \(String(format: "%3d", len + 1))    00 01 02 03 04 05 06 07   08 09 0A 0B 0C 0D 0E 0F\n"
    string += " bytes    -------------------------------------------------\n\n"
    
    string += "----- HEADER -----\n"
    
    var address = 0
    string += address.toHex() + "   "
    for i in 1...28 {
      string += String(format: "%02X", bytes[i-1]) + " "
      if (i % 8) == 0 { string += "  " }
      if (i % 16) == 0 {
        string += "\n"
        address += 16
        string += address.toHex() + "   "
      }
    }

    string += "\n\n----- PAYLOAD -----\n"
      
    
    string += address.toHex() + "                                         "
    for i in 29...len {
      string += String(format: "%02X", bytes[i-1]) + " "
      if (i % 8) == 0 { string += "  " }
      if (i % 16) == 0 {
        string += "\n"
        address += 16
        string += address.toHex() + "   "
      }
    }

    string += "\n\n----- PAYLOAD -----\n"
      
    
    string += address.toHex() + "                                         "
    for i in 29...len {
      string += String(decoding: bytes[i-1...i-1], as: UTF8.self) + "  "
      if (i % 8) == 0 { string += "  " }
      if (i % 16) == 0 {
        string += "\n"
        address += 16
        string += address.toHex() + "   "
      }
    }
    
    
    string += "\n\n----- PAYLOAD -----\n"
      

    let payloadBytes = bytes[27...len-1]
    let text = String(decoding: payloadBytes, as: UTF8.self)
    let lines = text.components(separatedBy: " ")
    let newText = lines.reduce("") {$0 + "<\($1)>\n"}
    string += newText
    
    
    string += "\n         -------------------------------------------------\n\n"
    return string
  }
}
