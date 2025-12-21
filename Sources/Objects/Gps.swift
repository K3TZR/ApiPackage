//
//  Gps.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

@MainActor
@Observable
public final class Gps {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init() {}

  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  //TODO:

  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse a Gps status message
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Gps.Property(rawValue: property.key)  else {
        // log it and ignore the Key
        apiLog(.propertyWarning, "Gps: unknown property, \(property.key) = \(property.value)", property.key) 
        continue
      }
      self.apply(property: token, value: property.value)
    }
    // is it initialized?
    if _initialized == false{
      // NO, it is now
      _initialized = true
      apiLog(.debug, "Gps: initialized") 
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Methods
  
  /// Apply a single property value
  /// - Parameters:
  ///   - property: Property enum value
  ///   - value: String to apply
  private func apply(property: Gps.Property, value: String) {
    switch property {
      
    case .altitude:       altitude = value
    case .frequencyError: frequencyError = value.dValue
    case .grid:           grid = value
    case .installed:      installed = value == "present" ? true : false
    case .latitude:       latitude = value
    case .longitude:      longitude = value
    case .speed:          speed = value
    case .time:           time = value
    case .track:          track = value.dValue
    case .tracked:        tracked = value.bValue
    case .visible:        visible = value.bValue
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  public var altitude = ""
  public var frequencyError: Double = 0
  public var grid = ""
  public var installed = false
  public var latitude = ""
  public var longitude = ""
  public var speed = ""
  public var time = ""
  public var track: Double = 0
  public var tracked = false
  public var visible = false

  public  enum Property: String {
    case altitude
    case frequencyError = "freq_error"
    case grid
    case latitude = "lat"
    case longitude = "lon"
    case speed
    case installed = "status"
    case time
    case track
    case tracked
    case visible
  }
  
  public var _initialized = false
}
