//
//  StreamModel.swift
//
//
//  Created by Douglas Adams on 3/22/24.
//

import Foundation

public enum StreamType: String {
  case daxIqStream = "dax_iq"
  case daxMicAudioStream = "dax_mic"
  case daxRxAudioStream = "dax_rx"
  case daxTxAudioStream = "dax_tx"
  case panadapter = "pan"
  case remoteRxAudioStream = "remote_audio_rx"
  case remoteTxAudioStream = "remote_audio_tx"
  case waterfall
}

public struct StreamStatus {
  public let type: VitaType
  public var packets = 0
  public var errors = 0
  
  public init(_ type: VitaType) {
    self.type = type
  }
}

public enum VitaType: String {
  case daxAudio
  case daxAudioReducedBw
  case daxIq24
  case daxIq48
  case daxIq96
  case daxIq192
  case meter
  case opus
  case panadapter
  case waterfall
}

final public class StreamModel: StreamProcessor, ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - initialization

  public init(_ apiModel: ApiModel) {
    api = apiModel
  }

  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  // Statistics
  
  @Published public var stats: [StreamStatus] = [
    StreamStatus(.daxAudio),            // = 0
    StreamStatus(.daxAudioReducedBw),   // = 1
    StreamStatus(.daxIq24),             // = 2
    StreamStatus(.daxIq48),             // = 3
    StreamStatus(.daxIq96),             // = 4
    StreamStatus(.daxIq192),            // = 5
    StreamStatus(.meter),               // = 6
    StreamStatus(.opus),                // = 7
    StreamStatus(.panadapter),          // = 8
    StreamStatus(.waterfall),           // = 9
  ]

  // single streams
//  public var daxMicAudioStream: DaxMicAudioStream?
//  public var daxTxAudioStream: DaxTxAudioStream?
  public var meterStream: MeterStream?
//  public var remoteRxAudioStream: RemoteRxAudioStream?
//  public var remoteTxAudioStream: RemoteTxAudioStream?

//  // collection streams
//  public var daxIqStreams = IdentifiedArrayOf<DaxIqStream>()
//  public var daxRxAudioStreams = IdentifiedArrayOf<DaxRxAudioStream>()
//  public var panadapterStreams = IdentifiedArrayOf<PanadapterStream>()
//  public var waterfallStreams = IdentifiedArrayOf<WaterfallStream>()
  
//  public var rxAudioOutput: RxAudioOutput?
//  public var daxAudioOutputs: [DaxAudioPlayer?] = Array(repeating: nil, count: 5)
  
  private let api: ApiModel
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  public func streamProcessor(_ vita: Vita) async {
    
    // pass Stream data to the appropriate Object
    switch vita.classCode {
    case .panadapter:
      await MainActor.run { stats[8].packets += 1  }
//      //      if let object = panadapterStreams[id: vita.streamId] { object.streamProcessor(vita) }
      break
      
    case .waterfall:
      await MainActor.run { stats[9].packets += 1  }
//      //      if let object = await waterfallStreams[id: vita.streamId] { object.streamProcessor(vita) }
      break
      
    case .daxIq24, .daxIq48, .daxIq96, .daxIq192:
//      //      if let object = daxIqStreams[id: vita.streamId] { object.streamProcessor(vita) }
      break
      
    case .daxAudio, .daxAudioReducedBw:
//      if daxRxAudioStreams[id: vita.streamId] == nil { daxRxAudioStreams.append( DaxRxAudioStream(vita.streamId)) }
//      await daxRxAudioStreams[id: vita.streamId]?.streamProcessor(vita)
      break
      
    case .meter:
      // update the statistics
      await MainActor.run { stats[6].packets += 1  }
      if meterStream == nil { meterStream = MeterStream(vita.streamId, apiModel: api) }
      meterStream?.streamProcessor(vita)
      
    case .opus:
//      if remoteRxAudioStream == nil { remoteRxAudioStream = RemoteRxAudioStream(vita.streamId) }
//      await remoteRxAudioStream?.streamProcessor(vita)
      break
      
    default:
      Task { await ApiLog.debug("StreamModel: unknown Vita class code: \(vita.classCode.description()) Stream Id = \(vita.streamId.hex)") }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: Public DAX Rx methods
  
//  public func daxRxAudioStop(_ channel: Int) {
//    Task {
//      for stream in daxRxAudioStreams where await stream.channel == channel {
//        await stream.stop()
//        await MainActor.run { ObjectModel.shared.sendTcp("stream remove \(stream.id.hex)") }
//        daxRxAudioStreams.remove(id: stream.id)
//      }
//    }
//  }
  
  // ----------------------------------------------------------------------------
  // MARK: Public Remote Audio methods
  
//  public func remoteRxAudioStop()  {
//    Task {
//      if let id = await remoteRxAudioStream?.stop() {
//        await MainActor.run { ObjectModel.shared.sendTcp("stream remove \(id.hex)")  }
//      }
//      remoteRxAudioStream = nil
//    }
//  }

//  public func remoteTxAudioStop()  {
//    Task {
//      if let id = await remoteTxAudioStream.stop() {
//        await MainActor.run { ObjectModel.shared.sendTcp("stream remove \(id.hex)")  }
//      }
//      remoteTxAudioStream = nil
//    }
//  }

  // ----------------------------------------------------------------------------
  // MARK: - Private Stream Status methods

  /// Evaluate a Status messaage
  /// - Parameters:
  ///   - properties: properties in KeyValuesArray form
//  private func daxIqStreamStatus(_ properties: KeyValuesArray) {
//    // get the id
//    if let id = properties[0].key.streamId {
//      // add it if not already present
//      if daxIqStreams[id: id] == nil { daxIqStreams.append( DaxIqStream(id) ) }
//      // parse the properties
//      daxIqStreams[id: id]!.parse( Array(properties.dropFirst(1)) )
//    }
//  }
//
//  private func daxTxAudioStreamStatus(_ properties: KeyValuesArray) {
//    // get the id
//    if let id = properties[0].key.streamId {
//      // add it if not already present
//      if daxTxAudioStream == nil { daxTxAudioStream = DaxTxAudioStream(id) }
//      // parse the properties
//      daxTxAudioStream?.parse( Array(properties.dropFirst(1)) )
//    }
//  }
//
//  private func remoteTxAudioStreamStatus(_ properties: KeyValuesArray) {
//    // get the id
//    if let id = properties[0].key.streamId {
//      // add it if not already present
//      if remoteTxAudioStream == nil { remoteTxAudioStream = RemoteTxAudioStream(id)  }
//      // parse the properties
//      remoteTxAudioStream?.parse( Array(properties.dropFirst(2)) )
//    }
//  }
  // ----------------------------------------------------------------------------
  // MARK: - Private Stream Helper methods

  /*
   "stream set 0x" + _streamId.ToString("X") + " daxiq_rate=" + _sampleRate
   "stream remove 0x" + _streamId.ToString("X")
   "stream set 0x" + _txStreamID.ToString("X") + " tx=" + Convert.ToByte(_transmit)
   "stream create type=dax_rx dax_channel=" + channel
   "stream create type=dax_mic"
   "stream create type=dax_tx"
   "stream create type=dax_iq daxiq_channel=" + channel
   "stream create type=remote_audio_rx"
   "stream create type=remote_audio_rx compression=opus"
   "stream create type=remote_audio_rx compression=none"
   "stream create type=remote_audio_tx"
   */
}
