//
//  GuiClient.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 11/17/24.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

public struct GuiClient: Equatable, Hashable, Identifiable, Sendable {
  public static func == (lhs: GuiClient, rhs: GuiClient) -> Bool {
    return lhs.handle == rhs.handle && lhs.station == rhs.station && lhs.program == rhs.program && lhs.ip == rhs.ip && lhs.host == rhs.host
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(handle)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(handle: String,
              station: String,
              program: String,
              ip: String = "",
              host: String = "",
              clientId: UUID? = nil,
              pttEnabled: Bool = false,
              available: Bool = true)
  {
    self.handle = handle
    self.station = station
    self.program = program
    self.ip = ip
    self.host = host

    self.clientId = clientId
    self.pttEnabled = pttEnabled
    self.available = available
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var handle: String
  public var station: String
  public var program: String
  public var ip: String
  public var host: String
  
  public var clientId: UUID?
  public var pttEnabled: Bool
  public var available: Bool
  
  public var id: String { handle }
}
