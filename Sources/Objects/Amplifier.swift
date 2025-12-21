//
//  Amplifier.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 8/7/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

@MainActor
@Observable
public final class Amplifier: Identifiable {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization

  public init(_ id: UInt32) {
    self.id = id
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray, _ inUse: Bool) {

    // get the id
    if let id = properties[0].key.objectId {
      let index = apiModel.amplifiers.firstIndex(where: { $0.id == id })
      
      // is it in use?
      if inUse {
        let amplifier: Amplifier
        if let index {
          // exists, retrieve
          amplifier = apiModel.amplifiers[index]
        } else {
          // new, add
          amplifier = Amplifier(id)
          apiModel.amplifiers.append(amplifier)
        }
        // parse
        amplifier.parse(Array(properties.dropFirst(1)) )
        
      } else {
        // remove
        if let index {
          apiModel.amplifiers.remove(at: index)
          apiLog(.debug, "Amplifier: REMOVED Id <\(id)>")
        } else {
          apiLog(.debug, "Amplifier: attempt to remove a non-existing entry")
        }
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse Tnf key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      guard let token = Amplifier.Property(rawValue: property.key) else {
        apiLog(.propertyWarning, "Amplifier: Id <\(self.id.hex)> unknown property <\(property.key) = \(property.value)>", property.key)
        continue
      }
      apply(property: token, value: property.value)
    }
    // is it initialized?
    if _initialized == false {
      // NO, it is now
      _initialized = true
      apiLog(.debug, "Amplifier: ADDED Id <\(self.id.hex)> model <\(self.model)>")
    }
  }
  
  /// Apply a single property value
  /// - Parameters:
  ///   - property: Property enum value
  ///   - value: String to apply
  private func apply(property: Amplifier.Property, value: String) {
    switch property {

    case .ant:          ant = value; antennaDict = antennaSettings(value)
    case .handle:       handle = value.handle ?? 0
    case .ip:           ip = value
    case .model:        model = value
    case .port:         port = value.iValue
    case .serialNumber: serialNumber = value
    case .state:        state = value
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private Helper methods
  
  /// Parse a list of antenna pairs
  /// - Parameter settings:     the list
  private func antennaSettings(_ settings: String) -> [String:String] {
    var antDict = [String:String]()
    
    // pairs are comma delimited
    let pairs = settings.split(separator: ",")
    // each setting is <ant:ant>
    for setting in pairs {
      if !setting.contains(":") { continue }
      let parts = setting.split(separator: ":")
      if parts.count != 2 {continue }
      antDict[String(parts[0])] = String(parts[1])
    }
    return antDict
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Properties
  
  public let id: UInt32

  public var ant: String = ""
  public var antennaDict = [String:String]()
  public var handle: UInt32 = 0
  public var ip: String = ""
  public var model: String = ""
  public var port: Int = 0
  public var serialNumber: String = ""
  public var state: String = ""
  
  public enum Property: String {
    case ant
    case handle
    case ip
    case model
    case port
    case serialNumber  = "serial_num"
    case state
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private Properties
  
  private var _initialized = false

  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  // TODO:
}

