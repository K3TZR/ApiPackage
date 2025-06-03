//
//  Profile.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

@MainActor
@Observable
public final class Profile {
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: String) {
    self.id = id
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static command methods
  
  /* ----- from the FlexApi source -----
   "profile transmit save \"" + profile_name.Replace("*","") + "\""
   "profile transmit create \"" + profile_name.Replace("*", "") + "\""
   "profile transmit reset \"" + profile_name.Replace("*", "") + "\""
   "profile transmit delete \"" + profile_name.Replace("*", "") + "\""
   "profile mic delete \"" + profile_name.Replace("*","") + "\""
   "profile mic save \"" + profile_name.Replace("*", "") + "\""
   "profile mic reset \"" + profile_name.Replace("*", "") + "\""
   "profile mic create \"" + profile_name.Replace("*", "") + "\""
   "profile global save \"" + profile_name + "\""
   "profile global delete \"" + profile_name + "\""
   
   "profile mic load \"" + _profileMICSelection + "\""
   "profile tx load \"" + _profileTXSelection + "\""
   "profile global load \"" + _profileGlobalSelection + "\""
   
   "profile global info"
   "profile tx info"
   "profile mic info"
   */
  
  // TODO:
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static status method
  
  public static func status(_ apiModel: ApiModel, _ properties: KeyValuesArray, _ inUse: Bool) {
    let components = properties[0].key.components(separatedBy: " ")
    
    guard components.count == 2 else {
      Task { await ApiLog.warning("Profile: unexpected format, \(properties[0].key)") }
      return
    }
    
    // get the id
    let id = components[0]
    let index = apiModel.profiles.firstIndex(where: { $0.id == id })
    // is it in use?
    if inUse {
      // YES, add it if not already present
      if index == nil {
        apiModel.profiles.append(Profile(id))
        Task { await ApiLog.debug("Profile: ADDED Id <\(id)>") }
        apiModel.profiles.last!.parse(properties)
      } else {
        // parse the properties
        apiModel.profiles[index!].parse(properties)
      }
      
    } else {
      // NO, remove it
      apiModel.profiles.remove(at: index!)
      Task { await ApiLog.debug("Profile: REMOVED Id <\(id)>") }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public parse method
  
  /// Parse Profile key/value pairs
  /// - Parameter statusMessage:       String
  public func parse(_ properties: KeyValuesArray) {
    let components = properties[0].key.components(separatedBy: " ")
    
    guard components.count == 2 else {
      Task { await ApiLog.warning("Profile: unexpected format, \(properties[0].key)") }
      return
    }
    
    // check for unknown Key
    guard let token = Profile.Property(rawValue: components[1]) else {
      // log it and ignore the Key
      Task { await ApiLog.warning("Profile: unknown property, \(properties[1].key)") }
      return
    }
    // known keys
    switch token {
    case .list:
      if properties.count < 2 {
        list = []
      } else {
        list = properties[1].key.valuesArray(delimiter: "^")
      }
      //      print("---->>>> list =", list)
      
    case .current:
      if properties.count < 2 {
        current = ""
      } else {
        current = properties[1].key
      }
      //      print("---->>>> current =", current)
      
    }
    // is it initialized?
    if _initialized == false {
      // NO, it is now
      _initialized = true
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Properties

  public let id: String
  
  public var current: String = ""
  public var list = [String]()
  
  public enum Property: String {
    case list = "list"
    case current = "current"
  }
  
  private var _initialized = false
}
