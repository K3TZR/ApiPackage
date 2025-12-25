//
//  Transmit.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 8/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

@MainActor
@Observable
public final class Transmit {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init() {}

  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  /* ----- from the FlexApi source -----
   transmit set am_carrier=" + _amCarrierLevel);
   transmit set compander=" + Convert.ToByte(_companderOn));
   transmit set compander_level=" + _companderLevel);
   transmit set dax=" + Convert.ToByte(_daxOn));
   transmit set filter_low=" + _txFilterLow + " filter_high=" + _txFilterHigh);
   transmit set hwalc_enabled=" + Convert.ToByte(_hwalcEnabled));
   transmit set inhibit=" + Convert.ToByte(_txInhibit));
   transmit set max_power_level=" + _maxPowerLevel);
   transmit set met_in_rx=" + Convert.ToByte(_met_in_rx));
   transmit set miclevel=" + _micLevel);
   transmit set mon=" + Convert.ToByte(_txMonitor));
   transmit set mon_gain_cw=" + _txCWMonitorGain);
   transmit set mon_gain_sb=" + _txSBMonitorGain);
   transmit set mon_pan_cw=" + _txCWMonitorPan);
   transmit set mon_pan_sb=" + _txSBMonitorPan);
   transmit set rfpower=" + _rfPower);
   transmit set show_tx_in_waterfall=" + Convert.ToByte(_showTxInWaterfall));
   transmit set speech_processor_enable=" + Convert.ToByte(_speechProcessorEnable));
   transmit set speech_processor_level=" + Convert.ToByte(_speechProcessorLevel));}
   transmit set tunepower=" + _tunePower);
   transmit set vox_delay=" + _simpleVOXDelay);
   transmit set vox_enable=" + Convert.ToByte(_simpleVOXEnable));
   transmit set vox_level=" + _simpleVOXLevel);
   
   transmit tune " + Convert.ToByte(_txTune));
   
   mic acc " + Convert.ToByte(_accOn));
   mic boost " + Convert.ToByte(_micBoost));
   mic bias " + Convert.ToByte(_micBias));
   mic input " + _micInput.ToUpper());
   
   cw break_in " + Convert.ToByte(_cwBreakIn));
   cw break_in_delay " + _cwDelay);
   cw cwl_enabled " + Convert.ToByte(_cwl_enabled));
   cw iambic " + Convert.ToByte(_cwIambic));
   cw mode 0");
   cw mode 1");
   cw pitch " + _cwPitch);
   cw sidetone " + Convert.ToByte(_cwSidetone));
   cw swap " + Convert.ToByte(_cwSwapPaddles));
   cw synccwx " + Convert.ToByte(_syncCWX));
   cw wpm " + _cwSpeed);
   
   cw key immediate " + Convert.ToByte(state));
   */
  
  public static func set(property: Property, value: String) -> String {
    
    switch property {
    case .micAccEnabled, .micBoostEnabled, .micBiasEnabled, .micSelection:
      return "mic \(property.rawValue) \(value)"
    
    case .cwBreakInEnabled, .cwBreakInDelay, .cwlEnabled, .cwIambicEnabled, .cwIambicMode, .cwPitch, .cwSidetoneEnabled, .cwSwapPaddles, .cwSyncCwxEnabled, .cwSpeed:
      return "cw \(property.rawValue) \(value)"
    
    default:
      return "transmit set \(property.rawValue)=\(value)"
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse a Transmit status message
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Transmit.Property(rawValue: property.key)  else {
        // log it and ignore the Key
        apiLog(.propertyWarning, "Transmit: unknown property, \(property.key) = \(property.value)", property.key)
        continue
      }
      self.apply(property: token, value: property.value)
    }
    // is it initialized?
    if _initialized == false {
      // NO, it is now
      _initialized = true
      apiLog(.debug, "Transmit: initialized")
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Methods
  
  /// Apply a single property value
  /// - Parameters:
  ///   - property: Property enum value
  ///   - value: String to apply
  private func apply(property: Transmit.Property, value: String) {
    switch property {
      
    case .amCarrierLevel:           carrierLevel = value.iValue
    case .companderEnabled:         companderEnabled = value.bValue
    case .companderLevel:           companderLevel = value.iValue
    case .cwBreakInEnabled:         cwBreakInEnabled = value.bValue
    case .cwBreakInDelay:           cwBreakInDelay = value.iValue
    case .cwIambicEnabled:          cwIambicEnabled = value.bValue
    case .cwIambicMode:             cwIambicMode = value.bValue
    case .cwlEnabled:               cwlEnabled = value.bValue
    case .cwMonitorGain:            cwMonitorGain = value.iValue
    case .cwMonitorPan:             cwMonitorPan = value.iValue
    case .cwPitch:                  cwPitch = value.iValue
    case .cwSidetoneEnabled:        cwSidetoneEnabled = value.bValue
    case .cwSpeed:                  cwSpeed = value.iValue
    case .cwSwapPaddles:            cwSwapPaddles = value.bValue
    case .cwSyncCwxEnabled:         cwSyncCwxEnabled = value.bValue
    case .daxEnabled:               daxEnabled = value.bValue
    case .frequency:                frequency = value.mhzToHz
    case .hwAlcEnabled:             hwAlcEnabled = value.bValue
    case .maxPowerLevel:            maxPowerLevel = value.iValue
    case .meterInRxEnabled:         meterInRxEnabled = value.bValue
    case .micAccEnabled:            micAccEnabled = value.bValue
    case .micBoostEnabled:          micBoostEnabled = value.bValue
    case .micBiasEnabled:           micBiasEnabled = value.bValue
    case .micLevel:                 micLevel = value.iValue
    case .micSelection:             micSelection = value
    case .mox:                      mox = value.bValue
    case .rawIqEnabled:             rawIqEnabled = value.bValue
    case .rfPower:                  rfPower = value.iValue
    case .speechProcessorEnabled:   speechProcessorEnabled = value.bValue
    case .speechProcessorLevel:     speechProcessorLevel = value.iValue
    case .ssbMonitorGain:           ssbMonitorGain = value.iValue
    case .ssbMonitorPan:            ssbMonitorPan = value.iValue
    case .tuneMode:                 tuneMode = value
    case .txAntenna:                txAntenna = value
    case .txFilterChanges:          txFilterChanges = value.bValue
    case .txFilterHigh:             txFilterHigh = value.iValue
    case .txFilterLow:              txFilterLow = value.iValue
    case .inhibit:                  inhibit = value.bValue
    case .txInWaterfallEnabled:     txInWaterfallEnabled = value.bValue
    case .txMonitorAvailable:       txMonitorAvailable = value.bValue
    case .txMonitorEnabled:         txMonitorEnabled = value.bValue
    case .txRfPowerChanges:         txRfPowerChanges = value.bValue
    case .txSliceMode:              txSliceMode = value
    case .tune:                     tune = value.bValue
    case .tunePower:                tunePower = value.iValue
    case .voxEnabled:               voxEnabled = value.bValue
    case .voxDelay:                 voxDelay = value.iValue
    case .voxLevel:                 voxLevel = value.iValue
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  public var carrierLevel = 0
  public var companderEnabled = false
  public var companderLevel = 0
  public var cwBreakInDelay = 0
  public var cwBreakInEnabled = false
  public var cwIambicEnabled = false
  public var cwIambicMode = false
  public var cwlEnabled = false
  public var cwMonitorGain = 0
  public var cwMonitorPan = 0
  public var cwPitch = 0
  public var cwSidetoneEnabled = false
  public var cwSpeed = 0
  public var cwSwapPaddles = false
  public var cwSyncCwxEnabled = false
  public var daxEnabled = false
  public var frequency: Hz = 0
  public var hwAlcEnabled = false
  public var maxPowerLevel = 0
  public var meterInRxEnabled = false
  public var micAccEnabled = false
  public var micBiasEnabled = false
  public var micBoostEnabled = false
  public var micLevel = 0
  public var micSelection = ""
  public var mox = false
  public var rawIqEnabled = false
  public var rfPower = 0
  public var speechProcessorEnabled = false
  public var speechProcessorLevel = 0
  public var ssbMonitorGain = 0
  public var ssbMonitorPan = 0
  public var tune = false
  public var tunePower = 0
  public var txAntenna = ""
  public var txFilterChanges = false
  public var txFilterHigh = 0
  public var txFilterLow = 0
  public var inhibit = false
  public var tuneMode = ""
  public var txInWaterfallEnabled = false
  public var txMonitorAvailable = false
  public var txMonitorEnabled = false
  public var txRfPowerChanges = false
  public var txSliceMode = ""
  public var voxEnabled = false
  public var voxDelay = 0
  public var voxLevel = 0
  
  public enum Property: String {
    // properties received from the radio                           // REQUIRED when sending to the radio
    case amCarrierLevel           = "am_carrier_level"              // "am_carrier"
    case companderEnabled         = "compander"
    case companderLevel           = "compander_level"
    case cwBreakInDelay           = "break_in_delay"
    case cwBreakInEnabled         = "break_in"
    case cwIambicEnabled          = "iambic"
    case cwIambicMode             = "iambic_mode"                   // "mode"
    case cwlEnabled               = "cwl_enabled"
    case cwMonitorGain            = "mon_gain_cw"
    case cwMonitorPan             = "mon_pan_cw"
    case cwPitch                  = "pitch"
    case cwSidetoneEnabled        = "sidetone"
    case cwSpeed                  = "speed"                         // "wpm"
    case cwSwapPaddles            = "swap_paddles"                  // "swap"
    case cwSyncCwxEnabled         = "synccwx"
    case daxEnabled               = "dax"
    case frequency                = "freq"
    case hwAlcEnabled             = "hwalc_enabled"
    case inhibit                  = "inhibit"
    case maxPowerLevel            = "max_power_level"
    case meterInRxEnabled         = "met_in_rx"
    case micAccEnabled            = "mic_acc"                       // "acc"
    case micBoostEnabled          = "mic_boost"                     // "boost"
    case micBiasEnabled           = "mic_bias"                      // "bias"
    case micLevel                 = "mic_level"                     // "miclevel"
    case micSelection             = "mic_selection"                 // "input"
    case mox
    case rawIqEnabled             = "raw_iq_enable"
    case rfPower                  = "rfpower"
    case speechProcessorEnabled   = "speech_processor_enable"
    case speechProcessorLevel     = "speech_processor_level"
    case ssbMonitorGain           = "mon_gain_sb"
    case ssbMonitorPan            = "mon_pan_sb"
    case tune
    case tuneMode                 = "tune_mode"
    case tunePower                = "tunepower"
    case txAntenna                = "tx_antenna"
    case txFilterChanges          = "tx_filter_changes_allowed"
    case txFilterHigh             = "hi"                            // "filter_high"
    case txFilterLow              = "lo"                            // "filter_low"
    case txInWaterfallEnabled     = "show_tx_in_waterfall"
    case txMonitorAvailable       = "mon_available"
    case txMonitorEnabled         = "sb_monitor"                    // "mon"
    case txRfPowerChanges         = "tx_rf_power_changes_allowed"
    case txSliceMode              = "tx_slice_mode"
    case voxEnabled               = "vox_enable"
    case voxDelay                 = "vox_delay"
    case voxLevel                 = "vox_level"
  }
  
  public enum AlternateProperty: String {
    // properties sent to the radio
    case amCarrierLevel           = "am_carrier"                    // "am_carrier"
    case cwIambicMode             = "mode"                          // "mode"
    case cwSpeed                  = "wpm"                           // "wpm"
    case cwSwapPaddles            = "swap"                          // "swap"
    case micAccEnabled            = "acc"                           // "acc"
    case micBoostEnabled          = "boost"                         // "boost"
    case micBiasEnabled           = "bias"                          // "bias"
    case micLevel                 = "miclevel"                      // "miclevel"
    case micSelection             = "input"                         // "input"
    case txFilterHigh             = "filter_high"                   // "filter_high"
    case txFilterLow              = "filter_low"                    // "filter_low"
    case txMonitorEnabled         = "mon"                           // "mon"
  }
  
  private var _initialized = false
}
