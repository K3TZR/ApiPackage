//
//  Slice.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 7/11/22.
//

import Foundation

@MainActor
@Observable
public final class Slice: Identifiable {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: UInt32) {
    self.id = id
    // set filterLow & filterHigh to default values
    setupDefaultFilters(mode)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  /* ----- from FlexApi -----
   "slice m " + StringHelper.DoubleToString(clicked_freq_MHz, "f6") + " pan=0x" + _streamID.ToString("X")
   "slice create"
   "slice set " + _index + " active=" + Convert.ToByte(_active)
   "slice set " + _index + " rxant=" + _rxant
   "slice set" + _index + " rfgain=" + _rfGain
   "slice set " + _index + " txant=" + _txant
   "slice set " + _index + " mode=" + _demodMode
   "slice set " + _index + " dax=" + _daxChannel
   "slice set " + _index + " rtty_mark=" + _rttyMark
   "slice set " + _index + " rtty_shift=" + _rttyShift
   "slice set " + _index + " digl_offset=" + _diglOffset
   "slice set " + _index + " digu_offset=" + _diguOffset
   "slice set " + _index + " audio_pan=" + _audioPan
   "slice set " + _index + " audio_level=" + _audioGain
   "slice set " + _index + " audio_mute=" + Convert.ToByte(value)
   "slice set " + _index + " anf=" + Convert.ToByte(value)
   "slice set " + _index + " apf=" + Convert.ToByte(value)
   "slice set " + _index + " anf_level=" + _anf_level
   "slice set " + _index + " apf_level=" + _apf_level
   "slice set " + _index + " diversity=" + Convert.ToByte(value)
   "slice set " + _index + " wnb=" + Convert.ToByte(value)
   "slice set " + _index + " nb=" + Convert.ToByte(value)
   "slice set " + _index + " wnb_level=" + _wnb_level)
   "slice set " + _index + " nb_level=" + _nb_level
   "slice set " + _index + " nr=" + Convert.ToByte(_nr_on)
   "slice set " + _index + " nr_level=" + _nr_level
   "slice set " + _index + " agc_mode=" + AGCModeToString(_agc_mode)
   "slice set " + _index + " agc_threshold=" + _agc_threshold
   "slice set " + _index + " agc_off_level=" + _agc_off_level
   "slice set " + _index + " tx=" + Convert.ToByte(_isTransmitSlice)
   "slice set " + _index + " loopa=" + Convert.ToByte(_loopA)
   "slice set " + _index + " loopb=" + Convert.ToByte(_loopB)
   "slice set " + _index + " rit_on=" + Convert.ToByte(_ritOn)
   "slice set " + _index + " rit_freq=" + _ritFreq
   "slice set " + _index + " xit_on=" + Convert.ToByte(_xitOn)
   "slice set " + _index + " xit_freq=" + _xitFreq
   "slice set " + _index + " step=" + _tuneStep
   "slice set " + _index + " record=" + Convert.ToByte(_record_on)
   "slice set " + _index + " play=" + Convert.ToByte(_playOn)
   "slice set " + _index + " fm_tone_mode=" + FMToneModeToString(_toneMode)
   "slice set " + _index + " fm_tone_value=" + _fmToneValue
   "slice set " + _index + " fm_deviation=" + _fmDeviation
   "slice set " + _index + " dfm_pre_de_emphasis=" + Convert.ToByte(_dfmPreDeEmphasis)
   "slice set " + _index + " squelch=" + Convert.ToByte(_squelchOn)
   "slice set " + _index + " squelch_level=" + _squelchLevel
   "slice set " + _index + " tx_offset_freq=" + StringHelper.DoubleToString(_txOffsetFreq, "f6")
   "slice set " + _index + " fm_repeater_offset_freq=" + StringHelper.DoubleToString(_fmRepeaterOffsetFreq, "f6")
   "slice set " + _index + " repeater_offset_dir=" + FMTXOffsetDirectionToString(_repeaterOffsetDirection)
   "slice set " + _index + " fm_tone_burst=" + Convert.ToByte(_fmTX1750)
   "slice remove " + _index
   "slice waveform_cmd " + _index + " " + s
   */
  
  public static func add(panadapterId: UInt32? = nil, mode: String = "", frequency: Hz = 0,  rxAntenna: String = "", usePersistence: Bool = false, replyHandler: ReplyHandler? = nil) -> String {
    var cmd = "slice create"
    if panadapterId != nil  { cmd += " pan=\(panadapterId!.hex)" }
    if frequency != 0     { cmd += " freq=\(frequency.hzToMhz)" }
    if rxAntenna != ""    { cmd += " rxant=\(rxAntenna)" }
    if mode != ""         { cmd += " mode=\(mode)" }
    if usePersistence     { cmd += " load_from=PERSISTENCE" }
    return cmd
  }
  public static func remove(id: UInt32) -> String {
    "slice remove \(id)"
  }
  public static func set(id: UInt32, property: Property, value: String) -> String {
    "tnf set \(id) \(property.rawValue)=\(value)"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray, _ inUse: Bool) {
    
    // get the id
    if let id = properties[0].key.objectId {
      let index = apiModel.slices.firstIndex(where: { $0.id == id })
      
      // is it in use?
      if inUse {
        let slice: Slice
        if let index {
          // exists, retrieve
          slice = apiModel.slices[index]
        } else {
          // new, add
          slice = Slice(id)
          apiModel.slices.append(slice)
        }
        // parse
        slice.parse(Array(properties.dropFirst(1)) )
        
      } else {
        // remove
        if let index {
          apiModel.slices.remove(at: index)
          apiLog(.debug, "Slice: REMOVED Id <\(id)>")
        } else {
          apiLog(.debug, "Slice: attempt to remove a non-existing entry")
        }
      }
    }
  }

//    // get the id
//    if let id = properties[0].key.objectId {
//      let index = apiModel.slices.firstIndex(where: { $0.id == id })
//      // is it in use?
//      if inUse {
//        if index == nil {
//          apiModel.slices.append(Slice(id))
//          apiModel.slices.last!.parse(Array(properties.dropFirst(1)) )
//        } else {
//          // parse the properties
//          apiModel.slices[index!].parse(Array(properties.dropFirst(1)) )
//        }
//        
//      } else {
//        // NO, remove it
//        apiModel.slices.remove(at: index!)
//        apiLog(.debug, "Slice: REMOVED Id <\(id)>")
//      }
//    }
//  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse key/value pairs
  /// - Parameter properties: a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Slice.Property(rawValue: property.key) else {
        // log it and ignore the Key
        apiLog(.propertyWarning, "Slice: Id <\(self.id.hex)> unknown property <\(property.key) = \(property.value)>", property.key)
        continue
      }
      self.apply(property: token, value: property.value)
    }
    // is it initialized?
    if _initialized == false && panadapterId != 0 && frequency != 0 && mode != "" {
      // NO, it is now
      _initialized = true
      apiLog(.debug, "Slice: ADDED Id <\(self.id.hex)> frequency <\(self.frequency.hzToMhz)> panadapter <\(self.panadapterId.hex)>") 
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Methods
  
  /// Apply a single property value
  /// - Parameters:
  ///   - property: Property enum value
  ///   - value: String to apply
  private func apply(property: Slice.Property, value: String) {
    switch property {
      
    case .active:                   active = value.bValue
    case .agcMode:                  agcMode = value
    case .agcOffLevel:              agcOffLevel = value.iValue
    case .agcThreshold:             agcThreshold = value.iValue
    case .anfAdaptMode:             anfAdaptMode = value.iValue
    case .anfDelay:                 anfDelay = value.iValue
    case .anfEnabled:               anfEnabled = value.bValue
    case .anfIsdftMode:             anfIsdftMode = value.bValue
    case .anfLevel:                 anfLevel = value.iValue
    case .anfWlen:                  anfWlen = value.iValue
    case .anfl:                     anfl = value.bValue
    case .anflLevel:                anflLevel = value.iValue
    case .anflFilterSize:           anflFilterSize = value.iValue
    case .anflDelay:                anflDelay = value.iValue
    case .anflLeakageLevel:         anflLeakageLevel = value.iValue
    case .anft:                     anft = value.bValue
    case .apfEnabled:               apfEnabled = value.bValue
    case .apfLevel:                 apfLevel = value.iValue
    case .audioGain:                audioGain = value.iValue
    case .audioLevel:               audioGain = value.iValue
    case .audioMute:                audioMute = value.bValue
    case .audioPan:                 audioPan = value.iValue
    case .clientHandle:             clientHandle = value.handle ?? 0
    case .daxChannel:
      if daxChannel != 0 && value.iValue == 0 {
        // remove this slice from the AudioStream it was using
        //          if let daxRxAudioStream = radio.findDaxRxAudioStream(with: daxChannel) { daxRxAudioStream.slice = nil }
      }
      daxChannel = value.iValue
    case .daxIqChannel:             daxIqChannel = value.iValue
    case .daxTxEnabled:             daxTxEnabled = value.bValue
    case .detached:                 detached = value.bValue
    case .dfmPreDeEmphasisEnabled:  dfmPreDeEmphasisEnabled = value.bValue
    case .digitalLowerOffset:       digitalLowerOffset = value.iValue
    case .digitalUpperOffset:       digitalUpperOffset = value.iValue
    case .diversityEnabled:         diversityEnabled = value.bValue
    case .diversityChild:           diversityChild = value.bValue
    case .diversityIndex:           diversityIndex = value.iValue
    case .esc:                      esc = value.bValue
    case .escGain:                  escGain = value.fValue
    case .escPhaseShift:            escPhaseShift = value.fValue
    case .filterHigh:               filterHigh = value.iValue
    case .filterLow:                filterLow = value.iValue
    case .fmDeviation:              fmDeviation = value.iValue
    case .fmRepeaterOffset:         fmRepeaterOffset = value.fValue
    case .fmToneBurstEnabled:       fmToneBurstEnabled = value.bValue
    case .fmToneMode:               fmToneMode = value
    case .fmToneFreq:               fmToneFreq = value.fValue
    case .frequency:                frequency = value.mhzToHz
    case .inUse:                    inUse = value.bValue
    case .locked:                   locked = value.bValue
    case .loopAEnabled:             loopAEnabled = value.bValue
    case .loopBEnabled:             loopBEnabled = value.bValue
    case .mode:                     mode = value.uppercased() ; filters = filterDefaults[mode]!
    case .modeList:                 modeList = value.list
    case .nbEnabled:                nbEnabled = value.bValue
    case .nbLevel:                  nbLevel = value.iValue
    case .nrAdaptMode:              nrAdaptMode = value.bValue
    case .nrDelay:                  nrDelay = value.iValue
    case .nrEnabled:                nrEnabled = value.bValue
    case .nrf:                      nrf = value.bValue
    case .nrfWinc:                  nrfWinc = value.iValue
    case .nrfWlen:                  nrfWlen = value.iValue
    case .nrIsdftMode:              nrIsdftMode = value.bValue
    case .nrl:                      nrl = value.bValue
    case .nrlDelay:                 nrlDelay = value.iValue
    case .nrlFilterSize:            nrlFilterSize = value.iValue
    case .nrlLeakageLevel:          nrlLeakageLevel = value.iValue
    case .nrlLevel:                 nrlLevel = value.iValue
    case .nrLevel:                  nrLevel = value.iValue
    case .nrWlen:                   nrWlen = value.iValue
    case .nr2:                      nr2 = value.iValue
    case .owner:                    nr2 = value.iValue
    case .panadapterId:             panadapterId = value.streamId ?? 0
    case .playbackEnabled:          playbackEnabled = (value == "enabled") || (value == "1")
    case .postDemodBypassEnabled:   postDemodBypassEnabled = value.bValue
    case .postDemodLow:             postDemodLow = value.iValue
    case .postDemodHigh:            postDemodHigh = value.iValue
    case .qskEnabled:               qskEnabled = value.bValue
    case .recordEnabled:            recordEnabled = value.bValue
    case .repeaterOffsetDirection:  repeaterOffsetDirection = value
    case .rfGain:                   rfGain = value.iValue
    case .ritOffset:                ritOffset = value.iValue
    case .ritEnabled:               ritEnabled = value.bValue
    case .rttyMark:                 rttyMark = value.iValue
    case .rttyShift:                rttyShift = value.iValue
    case .rxAnt:                    rxAnt = value
    case .rxErrormHz:               rxErrormHz = value.fValue
    case .rxAntList:                rxAntList = value.list
    case .sampleRate:               sampleRate = value.iValue         // FIXME: ????? not in v3.2.15 source code
    case .sliceLetter:              sliceLetter = value
    case .squelchAvgFactor:         squelchAvgFactor = value.iValue
    case .squelchEnabled:           squelchEnabled = value.bValue
    case .squelchHangDelay:         squelchHangDelay = value.iValue
    case .squelchLevel:             squelchLevel = value.iValue
    case .squelchTriggeredWeight:   squelchTriggeredWeight = value.iValue
    case .step:                     step = value.iValue
    case .stepList:                 stepList = value
    case .txEnabled:                txEnabled = value.bValue
    case .txAnt:                    txAnt = value
    case .txAntList:                txAntList = value.list
    case .txOffsetFreq:             txOffsetFreq = value.fValue
    case .wide:                     wide = value.bValue
    case .wnbEnabled:               wnbEnabled = value.bValue
    case .wnbLevel:                 wnbLevel = value.iValue
    case .xitOffset:                xitOffset = value.iValue
    case .xitEnabled:               xitEnabled = value.bValue
      
      // the following are ignored here
    case .daxClients:               break
    case .diversityParent:          break
    case .recordTime:               break
    case .ghost /*, .tune */:       break
    }
  }

  /// Set the default Filter widths
  /// - Parameters:
  ///   - mode:       demod mode
  ///
  private func setupDefaultFilters(_ mode: String) {
    if let modeValue = Mode(rawValue: mode) {
      switch modeValue {
        
      case .CW:
        filterLow = 450
        filterHigh = 750
      case .RTTY:
        filterLow = -285
        filterHigh = 115
      case .AM, .SAM:
        filterLow = -3_000
        filterHigh = 3_000
      case .FM, .NFM, .DFM:
        filterLow = -8_000
        filterHigh = 8_000
      case .LSB, .DIGL:
        filterLow = -2_400
        filterHigh = -300
      case .USB, .DIGU:
        filterLow = 300
        filterHigh = 2_400
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  static let kMinOffset = -99_999 // frequency offset range
  static let kMaxOffset = 99_999
  
  public let id: UInt32
  
  public var autoPan: Bool = false
  public var clientHandle: UInt32 = 0
  public var daxClients: Int = 0
  public var daxIqChannel = 0
  public var daxTxEnabled: Bool = false
  public var detached: Bool = false
  public var diversityChild: Bool = false
  public var diversityIndex: Int = 0
  public var diversityParent: Bool = false
  public var inUse: Bool = false
  public var modeList = [String]()
  public var nr2: Int = 0
  public var owner: Int = 0
  public var panadapterId: UInt32 = 0
  public var postDemodBypassEnabled: Bool = false
  public var postDemodHigh: Int = 0
  public var postDemodLow: Int = 0
  public var qskEnabled: Bool = false
  public var recordLength: Float = 0
  public var rxAntList = [String]()
  public var sliceLetter: String?
  public var txAntList = [String]()
  public var wide: Bool = false
  
  public var active: Bool = false
  public var agcMode: String = AgcMode.off.rawValue
  public var agcOffLevel: Int = 0
  public var agcThreshold = 0
  public var anfAdaptMode = 0
  public var anfDelay: Int = 0
  public var anfEnabled: Bool = false
  public var anfIsdftMode: Bool = false
  public var anfWlen: Int = 0
  public var anfLevel = 0
  public var anfl = false
  public var anflLevel = 0
  public var anflFilterSize = 0
  public var anflDelay = 0
  public var anflLeakageLevel = 0
  public var anft = false
  public var apfEnabled: Bool = false
  public var apfLevel: Int = 0
  public var audioGain = 0
  public var audioMute: Bool = false
  public var audioPan = 0
  public var daxChannel = 0
  public var dfmPreDeEmphasisEnabled: Bool = false
  public var digitalLowerOffset: Int = 0
  public var digitalUpperOffset: Int = 0
  public var diversityEnabled: Bool = false
  public var esc = false
  public var escGain: Float = 0
  public var escPhaseShift: Float = 0
  public var filterHigh: Int = 0
  public var filterLow: Int = 0
  public var fmDeviation: Int = 0
  public var fmRepeaterOffset: Float = 0
  public var fmToneBurstEnabled: Bool = false
  public var fmToneFreq: Float = 0
  public var fmToneMode: String = ""
  public var frequency: Hz = 0
  public var locked: Bool = false
  public var loopAEnabled: Bool = false
  public var loopBEnabled: Bool = false
  public var mode: String = ""
  public var nbEnabled: Bool = false
  public var nbLevel = 0
  public var nrAdaptMode = false
  public var nrDelay = 0
  public var nrEnabled: Bool = false
  public var nrf = false
  public var nrfWinc = 0
  public var nrfWlen = 0
  public var nrIsdftMode = false
  public var nrl = false
  public var nrlDelay = 0
  public var nrlFilterSize = 0
  public var nrlLeakageLevel = 0
  public var nrlLevel = 0
  public var nrLevel = 0
  public var nrWlen = 0
  public var playbackEnabled: Bool = false
  public var recordEnabled: Bool = false
  public var repeaterOffsetDirection: String = ""
  public var rfGain: Int = 0
  public var ritEnabled: Bool = false
  public var ritOffset: Int = 0
  public var rttyMark: Int = 0
  public var rttyShift: Int = 0
  public var rxAnt: String = ""
  public var rxErrormHz: Float = 0
  public var sampleRate: Int = 0
  public var splitId: UInt32?
  public var step: Int = 0
  public var stepList: String = "1, 10, 50, 100, 500, 1000, 2000, 3000"
  public var squelchAvgFactor = 0
  public var squelchEnabled: Bool = false
  public var squelchHangDelay = 0
  public var squelchLevel: Int = 0
  public var squelchTriggeredWeight = 0
  public var txAnt: String = ""
  public var txEnabled: Bool = false
  public var txOffsetFreq: Float = 0
  public var wnbEnabled: Bool = false
  public var wnbLevel = 0
  public var xitEnabled: Bool = false
  public var xitOffset: Int = 0
  
  public let daxChoices = Radio.kDaxChannels
  public var filters = [(low: Int, high: Int)]()
  
  let filterDefaults =     // Values of filters (by mode) (low, high)
  [
    "AM":   [(-1500,1500), (-2000,2000), (-2800,2800), (-3000,3000), (-4000,4000), (-5000,5000), (-6000,6000), (-7000,7000), (-8000,8000), (-10000,10000)],
    "SAM":  [(-1500,1500), (-2000,2000), (-2800,2800), (-3000,3000), (-4000,4000), (-5000,5000), (-6000,6000), (-7000,7000), (-8000,8000), (-10000,10000)],
    "CW":   [(450,500), (450,525), (450,550), (450,600), (450,700), (450,850), (450,1250), (450,1450), (450,1950), (450,3450)],
    "USB":  [(300,1500), (300,1700), (300,1900), (300,2100), (300,2400), (300,2700), (300,3000), (300,3200), (300,3600), (300,4300)],
    "LSB":  [(-1500,-300), (-1700,-300), (-1900,-300), (-2100,-300), (-2400,-300), (-2700,-300), (-3000,-300), (-3200,-300), (-3600,-300), (-4300,-300)],
    "FM":   [(-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000)],
    "NFM":  [(-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000)],
    "DFM":  [(-1500,1500), (-2000,2000), (-2800,2800), (-3000,3000), (-4000,4000), (-5000,5000), (-6000,6000), (-7000,7000), (-8000,8000), (-10000,10000)],
    "DIGU": [(300,1500), (300,1700), (300,1900), (300,2100), (300,2400), (300,2700), (300,3000), (300,3200), (300,3600), (300,4300)],
    "DIGL": [(-1500,-300), (-1700,-300), (-1900,-300), (-2100,-300), (-2400,-300), (-2700,-300), (-3000,-300), (-3200,-300), (-3600,-300), (-4300,-300)],
    "RTTY": [(-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115)]
  ]
  
  public enum Offset: String {
    case up
    case down
    case simplex
  }
  public enum AgcMode: String, CaseIterable {
    case off
    case slow
    case med
    case fast
    
    //    static func names() -> [String] {
    //      return [AgcMode.off.rawValue, AgcMode.slow.rawValue, AgcMode.med.rawValue, AgcMode.fast.rawValue]
    //    }
  }
  public enum Mode: String, CaseIterable {
    case AM
    case SAM
    case CW
    case USB
    case LSB
    case FM
    case NFM
    case DFM
    case DIGU
    case DIGL
    case RTTY
    //    case dsb
    //    case dstr
    //    case fdv
  }
  
  public enum Property: String, Equatable {
    case active
    case agcMode                    = "agc_mode"
    case agcOffLevel                = "agc_off_level"
    case agcThreshold               = "agc_threshold"
    case anfEnabled                 = "anf"
    case anfLevel                   = "anf_level"
    case anfAdaptMode               = "anf_adapt_mode"
    case anfDelay                   = "anf_delay"
    case anfIsdftMode               = "anf_isdft_mode"
    case anfWlen                    = "anf_wlen"
    case anfl                       = "anfl"
    case anflLevel                  = "anfl_level"
    case anflFilterSize             = "anfl_filter_size"
    case anflDelay                  = "anfl_delay"
    case anflLeakageLevel           = "anfl_leakage_level"
    case anft                       = "anft"
    case apfEnabled                 = "apf"
    case apfLevel                   = "apf_level"
    case audioGain                  = "audio_gain"
    case audioLevel                 = "audio_level"
    case audioMute                  = "audio_mute"
    case audioPan                   = "audio_pan"
    case clientHandle               = "client_handle"
    case daxChannel                 = "dax"
    case daxClients                 = "dax_clients"
    case daxIqChannel               = "dax_iq_channel"
    case daxTxEnabled               = "dax_tx"
    case detached
    case dfmPreDeEmphasisEnabled    = "dfm_pre_de_emphasis"
    case digitalLowerOffset         = "digl_offset"
    case digitalUpperOffset         = "digu_offset"
    case diversityEnabled           = "diversity"
    case diversityChild             = "diversity_child"
    case diversityIndex             = "diversity_index"
    case diversityParent            = "diversity_parent"
    case esc                        = "esc"
    case escGain                    = "esc_gain"
    case escPhaseShift              = "esc_phase_shift"
    case filterHigh                 = "filter_hi"
    case filterLow                  = "filter_lo"
    case fmDeviation                = "fm_deviation"
    case fmRepeaterOffset           = "fm_repeater_offset_freq"
    case fmToneBurstEnabled         = "fm_tone_burst"
    case fmToneMode                 = "fm_tone_mode"
    case fmToneFreq                 = "fm_tone_value"
    case frequency                  = "rf_frequency"
    case ghost
    case inUse                      = "in_use"
    case locked                     = "lock"
    case loopAEnabled               = "loopa"
    case loopBEnabled               = "loopb"
    case mode
    case modeList                   = "mode_list"
    case nbEnabled                  = "nb"
    case nbLevel                    = "nb_level"
    case nrDelay                    = "nr_delay"
    case nrAdaptMode                = "nr_adapt_mode"
    case nrEnabled                  = "nr"
    case nrf                        = "nrf"
    case nrfWinc                    = "nrf_winc"
    case nrfWlen                    = "nrf_wlen"
    case nrIsdftMode                = "nr_isdft_mode"
    case nrl                        = "nrl"
    case nrlDelay                   = "nrl_delay"
    case nrlFilterSize              = "nrl_filter_size"
    case nrlLeakageLevel            = "nrl_leakage_level"
    case nrlLevel                   = "nrl_level"
    case nrLevel                    = "nr_level"
    case nrWlen                     = "nr_wlen"
    case nr2
    case owner
    case panadapterId               = "pan"
    case playbackEnabled            = "play"
    case postDemodBypassEnabled     = "post_demod_bypass"
    case postDemodHigh              = "post_demod_high"
    case postDemodLow               = "post_demod_low"
    case qskEnabled                 = "qsk"
    case recordEnabled              = "record"
    case recordTime                 = "record_time"
    case repeaterOffsetDirection    = "repeater_offset_dir"
    case rfGain                     = "rfgain"
    case ritEnabled                 = "rit_on"
    case ritOffset                  = "rit_freq"
    case rttyMark                   = "rtty_mark"
    case rttyShift                  = "rtty_shift"
    case rxAnt                      = "rxant"
    case rxAntList                  = "ant_list"
    case rxErrormHz                 = "rx_error_mhz"
    case sampleRate                 = "sample_rate"
    case sliceLetter                = "index_letter"
    case squelchAvgFactor           = "squelch_avg_factor"
    case squelchHangDelay           = "squelch_hang_delay_ms"
    case squelchEnabled             = "squelch"
    case squelchLevel               = "squelch_level"
    case squelchTriggeredWeight     = "squelch_triggered_weight"
    
    case step
    case stepList                   = "step_list"
    //    case tune
    case txEnabled                  = "tx"
    case txAnt                      = "txant"
    case txAntList                  = "tx_ant_list"
    case txOffsetFreq               = "tx_offset_freq"
    case wide
    case wnbEnabled                 = "wnb"
    case wnbLevel                   = "wnb_level"
    case xitEnabled                 = "xit_on"
    case xitOffset                  = "xit_freq"
  }
  
  private var _initialized = false
}

