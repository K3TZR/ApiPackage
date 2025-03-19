//
//  Logging.swift
//
//
//  Created by Douglas Adams on 6/27/24.
//

import Foundation
import os

// Logger stub, must be initialized by app using this Package
public var log: Logger?

// ----------------------------------------------------------------------------
// MARK: - Logger Extension

extension Logger {
  public func warningExt(_ message: String) {
    ApiPackage.log?.warning("\(message)")
    NotificationCenter.default.post(name: Notification.Name.logAlert, object: AlertInfo("WARNING logged", message))
  }
  public func errorExt(_ message: String) {
    ApiPackage.log?.error("\(message)")
    NotificationCenter.default.post(name: Notification.Name.logAlert, object: AlertInfo("ERROR logged", message))
  }
}

extension Notification.Name {
  public static let logAlert = Notification.Name("LogAlert")
}

