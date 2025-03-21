//
//  GuiClient.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 11/17/24.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

public struct GuiClient: Identifiable, Hashable, Sendable {
  public static func == (lhs: GuiClient, rhs: GuiClient) -> Bool {
    return lhs.handle == rhs.handle
  }
  
  public func hash(into hasher: inout Hasher) {
      hasher.combine(handle) // Use only handle since it's the unique identifier
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(handle: String,
              station: String,
              program: String,
              ip: String = "",
              host: String = "",
              clientId: UUID? = nil,
              isLocalPtt: Bool = false,
              isAvailable: Bool = true)
  {
    self.handle = handle
    self.station = station
    self.program = program
    self.ip = ip
    self.host = host

    self.clientId = clientId
    self.isLocalPtt = isLocalPtt
    self.isAvailable = isAvailable
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var handle: String
  public var station: String
  public var program: String
  public var ip: String
  public var host: String
  
  public var clientId: UUID?
  public var isLocalPtt: Bool
  public var isAvailable: Bool
  
  public var id: String { handle }
}
