//  Vita.swift
//  SharedFeatures/Shared
//
//  Created by Douglas Adams on 5/9/17.
//

import Foundation

///  VITA struct implementation
///     this struct includes, in a more readily inspectable form, all of the properties
///     needed to populate a Vita Data packet. The "encode" instance method converts this
///     struct into a Vita Data packet. The "decode" static method converts a supplied
///     Vita Data packet into a Vita struct.
public struct Vita: Sendable {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Vita struct with the defaults above
  public init() {
    // nothing needed, all values are defaulted
  }
  
  /// Initialize Vita with specific settings
  /// - Parameters:
  ///   - type:           the type of Vita
  ///   - streamId:       a StreamId
  ///   - reducedBW:      is for reduced bandwidth
  ///
  public init(type: VitaTypes, streamId: UInt32, reducedBW: Bool = false) {
    switch type {
      
    case .discovery:    self.init(packetType: .extDataWithStream, classCode: .discovery, streamId: streamId, tsi: .utc, tsf: .sampleCount)
    case .netCW:        self.init(packetType: .extDataWithStream, classCode: .daxAudio, streamId: streamId, tsi: .other, tsf: .sampleCount)
    case .opusTxV2:     self.init(packetType: .extDataWithStream, classCode: .daxAudio, streamId: streamId, tsi: .other, tsf: .sampleCount)
    case .opusTx:       self.init(packetType: .extDataWithStream, classCode: .opus, streamId: streamId, tsi: .other, tsf: .sampleCount)
    case .txAudio:
      var classCode = ClassCode.daxAudio
      if reducedBW { classCode = ClassCode.daxAudioReducedBw }
      self.init(packetType: .ifDataWithStream, classCode: classCode, streamId: streamId, tsi: .other, tsf: .sampleCount)
    }
  }
  
  /// Initialize a Vita struct as a dataWithStream (Ext or If)
  /// - Parameters:
  ///   - packetType:     a Vita Packet Type (.extDataWithStream || .ifDataWithStream)
  ///   - classCode:      a Vita Class Code
  ///   - streamId:       a Stream ID (as a String, no "0x")
  ///   - tsi:            the type of Integer Time Stamp
  ///   - tsf:            the type of Fractional Time Stamp
  /// - Returns:          a partially populated Vita struct
  init(packetType: PacketTypes, classCode: ClassCode, streamId: UInt32, tsi: TsiTypes, tsf: TsfTypes) {
    assert(packetType == .extDataWithStream || packetType == .ifDataWithStream)
    
    self.packetType = packetType
    self.classCode = classCode
    self.streamId = streamId
    self.tsiType = tsi
    self.tsfType = tsf
    if tsi == .utc {
      self.integerTimestamp = CFSwapInt32HostToBig(UInt32(Date().timeIntervalSince1970))
    }
  }
  
  /// Decode a Data type into a Vita struct
  /// - Parameter data:         a Data type containing a Vita stream
  /// - Returns:                a Vita struct
  ///
  public static func decode(from data: Data) -> Vita? {
    let minHeaderBytes = MemoryLayout<VitaHeader>.size
    let packetTypeMask: UInt8 = 0xf0
    let classIdPresentMask: UInt8 = 0x08
    let trailerPresentMask: UInt8 = 0x04
    let tsiTypeMask: UInt8 = 0xc0
    let tsfTypeMask: UInt8 = 0x30
    let packetSequenceMask: UInt8 = 0x0f
    let informationClassCodeMask: UInt32 = 0xffff0000
    let classCodeMask: UInt32 = 0x0000ffff
    let trailerSize = 4

    guard data.count >= minHeaderBytes else { return nil }

    var vita = Vita()

    return data.withUnsafeBytes { rawBuf -> Vita? in
      guard let base = rawBuf.baseAddress else { return nil }

      // Load header safely
      let header = rawBuf.load(fromByteOffset: 0, as: VitaHeader.self)

      // Validate OUI
      guard CFSwapInt32BigToHost(header.oui) == Vita.kFlexOui else { return nil }

      // Packet type
      guard let pt = PacketTypes(rawValue: (header.packetDesc & packetTypeMask) >> 4) else { return nil }
      guard pt == .ifDataWithStream || pt == .extDataWithStream else { return nil }
      vita.packetType = pt

      // Flags
      vita.classIdPresent = (header.packetDesc & classIdPresentMask) == classIdPresentMask
      vita.trailerPresent = (header.packetDesc & trailerPresentMask) == trailerPresentMask

      // Timestamps and sequence
      guard let intStamp = TsiTypes(rawValue: (header.timeStampDesc & tsiTypeMask) >> 6) else { return nil }
      guard let fracStamp = TsfTypes(rawValue: (header.timeStampDesc & tsfTypeMask) >> 4) else { return nil }
      vita.tsiType = intStamp
      vita.tsfType = fracStamp
      vita.sequence = Int(header.timeStampDesc & packetSequenceMask)

      // Packet size in bytes (header.packetSize is in 32-bit words)
      let packetSizeWordsBE = header.packetSize
      let packetSizeWords = Int(CFSwapInt16BigToHost(packetSizeWordsBE))
      let packetSizeBytes = packetSizeWords * 4
      vita.packetSize = packetSizeBytes

      // Optional fields start after first 4 bytes (packetDesc/timeStampDesc/packetSize)
      var headerCountWords = 0
      let optionalsOffsetBytes = 4 // after first 32-bit word

      // Stream ID (present for withStream types)
      if pt == .ifDataWithStream || pt == .extDataWithStream {
        let byteOffset = optionalsOffsetBytes + headerCountWords * 4
        guard data.count >= byteOffset + 4 else { return nil }
        let streamIdBE: UInt32 = rawBuf.load(fromByteOffset: byteOffset, as: UInt32.self)
        vita.streamId = CFSwapInt32BigToHost(streamIdBE)
        headerCountWords += 1
      }

      // Class ID present?
      if vita.classIdPresent {
        let ouiOffset = optionalsOffsetBytes + headerCountWords * 4
        let classCodesOffset = optionalsOffsetBytes + (headerCountWords + 1) * 4
        guard data.count >= classCodesOffset + 4 else { return nil }

        let ouiBE: UInt32 = rawBuf.load(fromByteOffset: ouiOffset, as: UInt32.self)
        vita.oui = CFSwapInt32BigToHost(ouiBE) & kOuiMask

        let classCodesBE: UInt32 = rawBuf.load(fromByteOffset: classCodesOffset, as: UInt32.self)
        let classCodes = CFSwapInt32BigToHost(classCodesBE)
        vita.informationClassCode = (classCodes & informationClassCodeMask) >> 16
        guard let cc = ClassCode(rawValue: UInt16(classCodes & classCodeMask)) else { return nil }
        vita.classCode = cc

        headerCountWords += 2
      }

      // Integer timestamp (if any)
      if vita.tsiType != .none {
        let byteOffset = optionalsOffsetBytes + headerCountWords * 4
        guard data.count >= byteOffset + 4 else { return nil }
        let intTsBE: UInt32 = rawBuf.load(fromByteOffset: byteOffset, as: UInt32.self)
        vita.integerTimestamp = CFSwapInt32BigToHost(intTsBE)
        headerCountWords += 1
      }

      // Fractional timestamp (if any)
      if vita.tsfType != .none {
        let msbOffset = optionalsOffsetBytes + headerCountWords * 4
        let lsbOffset = optionalsOffsetBytes + (headerCountWords + 1) * 4
        guard data.count >= lsbOffset + 4 else { return nil }
        let fracMsbBE: UInt32 = rawBuf.load(fromByteOffset: msbOffset, as: UInt32.self)
        let fracLsbBE: UInt32 = rawBuf.load(fromByteOffset: lsbOffset, as: UInt32.self)
        vita.fracTimeStampMsb = CFSwapInt32BigToHost(fracMsbBE)
        vita.fracTimeStampLsb = CFSwapInt32BigToHost(fracLsbBE)
        headerCountWords += 2
      }

      // Compute header size in bytes (first 32-bit word + optionals)
      vita.headerSize = 4 * (headerCountWords + 1)

      // Compute payload size in bytes
      let trailerBytes = vita.trailerPresent ? trailerSize : 0
      guard data.count >= vita.headerSize + trailerBytes else { return nil }
      vita.payloadSize = data.count - vita.headerSize - trailerBytes

      // Copy payload
      vita.payloadData = [UInt8](repeating: 0x00, count: vita.payloadSize)
      if vita.payloadSize > 0 {
        let payloadRange = vita.headerSize..<(vita.headerSize + vita.payloadSize)
        vita.payloadData.replaceSubrange(0..<vita.payloadSize, with: data[payloadRange])
      }

      // Trailer
      if vita.trailerPresent {
        let trailerOffset = data.count - 4
        let trailerBE: UInt32 = rawBuf.load(fromByteOffset: trailerOffset, as: UInt32.self)
        vita.trailer = CFSwapInt32BigToHost(trailerBE)
      }

      return vita
    }
  }
  
  /// Encode a Vita struct as a Data type
  /// - Returns:          a Data type containing the Vita stream
  public static func encodeAsData(_ vita: Vita, sequenceNumber: UInt8) -> Data? {
    // TODO: Handle optional fields
    
    // create a Header struct
    var header = VitaHeader()
    
    // populate the header fields from the Vita struct
    
    // packet type
    header.packetDesc = (vita.packetType.rawValue & 0x0f) << 4
    
    // class id & trailer flags
    if vita.classIdPresent { header.packetDesc |= Vita.kClassIdPresentMask }
    if vita.trailerPresent { header.packetDesc |= Vita.kTrailerPresentMask }
    
    // time stamps
    header.timeStampDesc = ((vita.tsiType.rawValue & 0x03) << 6) | ((vita.tsfType.rawValue & 0x03) << 4) | (sequenceNumber & 0x0f)
    
    header.integerTimeStamp = CFSwapInt32HostToBig(vita.integerTimestamp)
    header.fractionalTimeStampLsb = CFSwapInt32HostToBig(vita.fracTimeStampLsb)
    header.fractionalTimeStampMsb = CFSwapInt32HostToBig(vita.fracTimeStampMsb)
    
    // sequence number
    header.timeStampDesc |= (UInt8(vita.sequence) & 0x0f)
    
    // oui
    header.oui = CFSwapInt32HostToBig(Vita.kFlexOui & Vita.kOuiMask)
    
    // class codes
    let classCodes = UInt32(vita.informationClassCode << 16) | UInt32(vita.classCode.rawValue)
    header.classCodes = CFSwapInt32HostToBig(classCodes)
    
    // packet size (round up to allow for OpusTx with payload bytes not a multiple of 4)
    let adjustedPacketSize = UInt16( (Float(vita.packetSize) / 4.0).rounded(.up))
    header.packetSize = CFSwapInt16HostToBig( adjustedPacketSize )
    
    // stream id
    header.streamId = CFSwapInt32HostToBig(vita.streamId)
    
    // create the Data type and populate it with the VitaHeader
    var headerCopy = header
    var data = Data(bytes: &headerCopy, count: MemoryLayout<VitaHeader>.size)
    
    // append the payload bytes
    data.append(contentsOf: vita.payloadData.prefix(vita.payloadSize))
    
    // is there a Trailer?
    if vita.trailerPresent {
      // YES, append the trailer bytes using a local mutable copy
      var trailerCopy = vita.trailer
      data.append(Data(bytes: &trailerCopy, count: MemoryLayout<UInt32>.size))
    }
    
    // pad to 32 bit boundary with nulls
    let null: [UInt8] = [0]
    if vita.packetSize % 4 != 0 {
      data.append(null, count: 4 - (vita.packetSize % 4))
    }
    
    
    
    // return the Data type
    return data
  }
  
  /// Create a Data type containing a Vita Discovery packet
  /// - Parameter payload:        the Discovery payload (as an array of String)
  /// - Returns:                  a Data type containing a Vita Discovery packet
  public static func discovery(payload: [String], sequenceNumber: UInt8) -> Data? {
    // create a new Vita struct (w/defaults & extDataWithStream / Discovery)
    var vita = Vita(type: .discovery, streamId: Vita.DiscoveryStreamId)
    
    // concatenate the strings, separated by space
    let payloadString = payload.joined(separator: " ")
    
    // calculate the actual length of the payload (in bytes)
    vita.payloadSize = payloadString.lengthOfBytes(using: .ascii)
    
    //        // calculate the number of UInt32 that can contain the payload bytes
    //        let payloadWords = Int((Float(vita.payloadSize) / Float(MemoryLayout<UInt32>.size)).rounded(.awayFromZero))
    //        let payloadBytes = payloadWords * MemoryLayout<UInt32>.size
    
    // create the payload array at the appropriate size (always a multiple of UInt32 size)
    var payloadArray = [UInt8](repeating: 0x20, count: vita.payloadSize)
    
    // packet size is Header + Payload (no Trailer)
    vita.packetSize = vita.payloadSize + MemoryLayout<VitaHeader>.size
    
    // convert the payload to an array of UInt8
    let cString = payloadString.cString(using: .ascii)!
    for i in 0..<cString.count - 1 {
      payloadArray[i] = UInt8(cString[i])
    }
    // give the Vita struct a pointer to the payload
    vita.payloadData = payloadArray
    
    // return the encoded Vita struct as Data
    return Vita.encodeAsData(vita, sequenceNumber: sequenceNumber)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  public static let DiscoveryStreamId              : UInt32 = 0x00000800

  public var classCode                             : ClassCode = .panadapter      // Packet class code
  public var classIdPresent                        : Bool = true                  // Class ID present
  public var packetSize                            : Int = 0                      // Size of packet (32 bit chunks)
  public var payloadData                           = [UInt8]()                    // Array of bytes in payload
  public var payloadSize                           : Int = 0                      // Size of payload (bytes)
  public var streamId                              : UInt32 = 0                   // Stream ID
  
  // filled with defaults, values are changed when created
  //      Types are shown for clarity
  
  public var packetType                     : PacketTypes = .extDataWithStream    // Packet type
  public var trailerPresent                 : Bool = false                        // Trailer present
  public var tsiType                        : TsiTypes = .utc                     // Integer timestamp type
  public var tsfType                        : TsfTypes = .sampleCount             // Fractional timestamp type
  public var sequence                       : Int = 0                             // Mod 16 packet sequence number
  public var integerTimestamp               : UInt32 = 0                          // Integer portion
  public var fracTimeStampMsb               : UInt32 = 0                          // fractional portion - MSB 32 bits
  public var fracTimeStampLsb               : UInt32 = 0                          // fractional portion -LSB 32 bits
  public var oui                            : UInt32 = kFlexOui                   // Flex Radio oui
  public var informationClassCode           : UInt32 = kFlexInformationClassCode  // Flex Radio classCode
  public var trailer                        : UInt32 = 0                          // Trailer, 4 bytes (if used)
  public var headerSize                     : Int = MemoryLayout<VitaHeader>.size // Header size (bytes)

  // Flex specific codes
  static let kFlexOui                       : UInt32 = 0x1c2d
  static let kOuiMask                       : UInt32 = 0x00ffffff
  static let kFlexInformationClassCode      : UInt32 = 0x534c
  
  static let kClassIdPresentMask            : UInt8 = 0x08
  static let kTrailerPresentMask            : UInt8 = 0x04
}

// ----------------------------------------------------------------------------
// MARK: - Vita types

extension Vita {
  ///  VITA header struct implementation
  ///      provides decoding and encoding services for Vita encoding
  ///      see http://www.vita.com
  public struct VitaHeader {
    // this struct mirrors the structure of a Vita Header
    //      some of these fields are optional in a generic Vita-49 header
    //      however they are always present in the Flex usage of Vita-49
    //
    //      all of the UInt16 & UInt32 fields must be BigEndian
    //
    //      This header is 28 bytes / 4 UInt32's
    //
    public var packetDesc                            : UInt8 = 0
    public var timeStampDesc                         : UInt8 = 0   // the lsb four bits are used for sequence number
    public var packetSize                            : UInt16 = 0
    public var streamId                              : UInt32 = 0
    public var oui                                   : UInt32 = 0
    public var classCodes                            : UInt32 = 0
    public var integerTimeStamp                      : UInt32 = 0
    public var fractionalTimeStampMsb                : UInt32 = 0
    public var fractionalTimeStampLsb                : UInt32 = 0
  }

  /// Types
  public  enum VitaTypes {
    case discovery
    case netCW
    case opusTxV2
    case opusTx
    case txAudio
  }
  
  /// Packet Types
  public enum PacketTypes : UInt8, Sendable {          // Packet Types
    case ifData             = 0x00
    case ifDataWithStream   = 0x01
    case extData            = 0x02
    case extDataWithStream  = 0x03
    case ifContext          = 0x04
    case extContext         = 0x05
    
    public func description() -> String {
      switch self {
      case .ifData:             return "IfData"
      case .ifDataWithStream:   return "IfDataWithStream"
      case .extData:            return "ExtData"
      case .extDataWithStream:  return "ExtDataWithStream"
      case .ifContext:          return "IfContext"
      case .extContext:         return "ExtContext"
      }
    }
  }
  
  /// Tsi Types
  public enum TsiTypes : UInt8, Sendable {             // Timestamp - Integer
    case none   = 0x00
    case utc    = 0x01
    case gps    = 0x02
    case other  = 0x03
    
    public func description() -> String {
      switch self {
      case .none:   return "None"
      case .utc:    return "Utc"
      case .gps:    return "Gps"
      case .other:  return "Other"
      }
    }
  }
  
  /// Tsf Types
  public enum TsfTypes : UInt8, Sendable {             // Timestamp - Fractional
    case none         = 0x00
    case sampleCount  = 0x01
    case realtime     = 0x02
    case freeRunning  = 0x03
    
    public func description() -> String {
      switch self {
      case .none:         return "None"
      case .sampleCount:  return "SampleCount"
      case .realtime:     return "Realtime"
      case .freeRunning:  return "FreeRunning"
      }
    }
  }
  
  /// Class codes
  public enum ClassCode: UInt16, Sendable {    // Packet Class Codes
    case daxAudio          = 0x03e3
    case daxAudioReducedBw = 0x0123
    case daxIq24           = 0x02e3
    case daxIq48           = 0x02e4
    case daxIq96           = 0x02e5
    case daxIq192          = 0x02e6
    case discovery         = 0xffff
    case meter             = 0x8002
    case opus              = 0x8005
    case panadapter        = 0x8003
    case waterfall         = 0x8004

    public func description() -> String {
      switch self {
      case .daxAudio:          return "DaxAudio"
      case .daxAudioReducedBw: return "DaxAudioReducedBw"
      case .daxIq24:           return "DaxIq24"
      case .daxIq48:           return "DaxIq48"
      case .daxIq96:           return "DaxIq96"
      case .daxIq192:          return "DaxIq192"
      case .discovery:         return "Discovery"
      case .meter:             return "Meter"
      case .opus:              return "Opus"
      case .panadapter:        return "Panadapter"
      case .waterfall:         return "Waterfall"
      }
    }
  }
}

// ----------------------------------------------------------------------------
// MARK: - Protocols

public protocol StreamProcessor: AnyObject {
  func streamProcessor(_ vita: Vita) async
}

public protocol AudioProcessor: AnyObject {
  func audioProcessor(_ vita: Vita)
}

// MARK: - Vita Helpers (Discovery)

import Foundation

public enum VitaDecodingError: Error {
  case invalidPacket
  case notDiscovery
  case invalidUTF8
}

public extension Vita {
  /// A throwing wrapper around the existing optional decode API.
  /// Throws `VitaDecodingError.invalidPacket` if decoding fails.
  static func decodeThrowing(from data: Data) throws -> Vita {
    guard let vita = Self.decode(from: data) else {
      throw VitaDecodingError.invalidPacket
    }
    return vita
  }

  /// Returns true if this Vita packet represents a Discovery packet.
  func isDiscoveryPacket() -> Bool {
    return self.classIdPresent && self.classCode == .discovery
  }

  /// Parses the discovery payload into key/value pairs.
  /// - Parameter strict: If true, throws on malformed pairs; otherwise skips them.
  func parseDiscoveryProperties(strict: Bool = false) throws -> [(key: String, value: String)] {
    guard isDiscoveryPacket() else { throw VitaDecodingError.notDiscovery }
    guard let raw = String(data: Data(self.payloadData), encoding: .utf8) else {
      throw VitaDecodingError.invalidUTF8
    }
    let cleaned = raw
      .trimmingCharacters(in: .controlCharacters)
      .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))

    var result: [(key: String, value: String)] = []
    for part in cleaned.split(separator: " ") {
      guard let eq = part.firstIndex(of: "=") else {
        if strict { throw VitaDecodingError.invalidPacket } else { continue }
      }
      let key = String(part[..<eq])
      let value = String(part[part.index(after: eq)...])
      result.append((key, value))
    }
    return result
  }
}

