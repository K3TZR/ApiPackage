//
//  Logging.swift
//
//
//  Created by Douglas Adams on 6/27/24.
//

import Foundation
import os

// Logger stub, must be initialized by app using this Package
//public var log: Logger?

// ----------------------------------------------------------------------------
// MARK: - Logger Extension

//extension Logger {
//  public func warningExt(_ message: String) {
//    ApiPackage.Task { await ApiLog.warning("\(message)")
//    NotificationCenter.default.post(name: Notification.Name.logAlert, object: AlertInfo("WARNING logged", message))
//  }
//  public func errorExt(_ message: String) {
//    ApiPackage.Task { await ApiLog.error("\(message)")
//    NotificationCenter.default.post(name: Notification.Name.logAlert, object: AlertInfo("ERROR logged", message))
//  }
//}

extension Notification.Name {
  public static let logAlertWarning = Notification.Name("LogAlertWarning")
  public static let logAlertError = Notification.Name("LogAlertError")
}

public actor ApiLog: LoggingActor {
  private let _logger: Logger
  
  public static let shared = ApiLog()
  
  private init() {
    _logger = Logger(subsystem: "net.k3tzr.ApiPackage", category: "Package")
  }
  
  public func debug(_ message: String) async {
    _logger.debug("\(message)")
  }
  
  public func info(_ message: String) async {
    _logger.info("\(message)")
  }
  
  public func warning(_ message: String) async {
    _logger.warning("\(message)")
    NotificationCenter.default.post(
      name: Notification.Name.logAlertWarning,
      object: AlertInfo("A Warning has been logged", message)
    )
  }
  
  public func error(_ message: String) async {
    _logger.error("\(message)")
    NotificationCenter.default.post(
      name: Notification.Name.logAlertError,
      object: AlertInfo("An Error has been logged", message)
    )
  }
}

extension ApiLog {
  public static func debug(_ message: String) async {
    await shared.debug(message)
  }
  public static func info(_ message: String) async {
    await shared.info(message)
  }
  public static func warning(_ message: String) async {
    await shared.warning(message)
  }
  public static func error(_ message: String) async {
    await shared.error(message)
  }
}


public protocol LoggingActor {
  func debug(_ message: String) async
  func info(_ message: String) async
  func warning(_ message: String) async
  func error(_ message: String) async
}
