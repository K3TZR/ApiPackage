//
//  Atu.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

@MainActor
@Observable
public final class Atu {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init() {}
  
  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse status message
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Atu.Property(rawValue: property.key)  else {
        // log it and ignore the Key
        apiLog(.propertyWarning, "Atu: unknown property <\(property.key) = \(property.value)>", property.key)
        continue
      }
      self.apply(property: token, value: property.value)
    }
    // is it initialized?
    if _initialized == false{
      // NO, it is now
      _initialized = true
      apiLog(.debug, "Atu: ADDED") 
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Methods
  
  /// Apply a single property value
  /// - Parameters:
  ///   - property: Property enum value
  ///   - value: String to apply
   private func apply(property: Atu.Property, value: String) {
     switch property {
       
     case .enabled:          enabled = value.bValue
     case .memoriesEnabled:  memoriesEnabled = value.bValue
     case .status:           status = Atu.Status(rawValue: value) ?? .none
     case .usingMemory:      usingMemory = value.bValue
     }
   }

  // ----------------------------------------------------------------------------
  // MARK: - Public Properties
  
  public var enabled: Bool = false
  public var memoriesEnabled: Bool = false
  public var status: Status = .none
  public var usingMemory: Bool = false
  
  public enum Status: String {
    case none             = "NONE"
    case tuneNotStarted   = "TUNE_NOT_STARTED"
    case tuneInProgress   = "TUNE_IN_PROGRESS"
    case tuneBypass       = "TUNE_BYPASS"           // Success Byp
    case tuneSuccessful   = "TUNE_SUCCESSFUL"       // Success
    case tuneOK           = "TUNE_OK"
    case tuneFailBypass   = "TUNE_FAIL_BYPASS"      // Byp
    case tuneFail         = "TUNE_FAIL"
    case tuneAborted      = "TUNE_ABORTED"
    case tuneManualBypass = "TUNE_MANUAL_BYPASS"    // Byp
  }
  
  public enum Property: String {
    case status
    case enabled            = "atu_enabled"
    case memoriesEnabled    = "memories_enabled"
    case usingMemory        = "using_mem"
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private Properties
  
  private var _initialized = false

  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods

  /* ----- from the FlexApi source -----
   "atu bypass"
   "atu clear"
   "atu set memories_enabled=" + Convert.ToByte(_atuMemoriesEnabled)
   "atu start"
   */

  public static func bypass() -> String {
    "atu bypass"
  }
  public static func clear() -> String {
    "atu clear"
  }
  public static func set(id: UInt32, property: Property, value: String) -> String {
    "atu set \(property.rawValue)=\(value)"
  }
  public static func start() -> String {
    "atu start"
  }
}

