//
//  Waveform.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 8/17/17.
//

import Foundation

@MainActor
@Observable
public final class Waveform {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization

  public init() {}

  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  /* ----- from the FlexApi source -----
   "waveform uninstall " + waveform_name
   */

  public static func uninstall(name: String) -> String {
    "waveform uninstall \(name)"
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse a Waveform status message
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Waveform.Property(rawValue: property.key)  else {
        // log it and ignore the Key
        Task { await ApiLog.warning("Waveform: unknown property <\(property.key) = \(property.value)>") }
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .list:   list = property.value
      }
    }
    // is it initialized?
    if _initialized == false {
      // NO, it is now
      _initialized = true
      Task { await ApiLog.debug("Waveform: initialized") }
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Properties

  public var list = ""
  
  public enum Property: String {
    case list = "installed_list"
  }
  
  private var _initialized  = false
}
