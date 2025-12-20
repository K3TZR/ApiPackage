//
//  Logging.swift
//
//
//  Created by Douglas Adams on 6/27/24.
//

import Foundation
import os

// ----------------------------------------------------------------------------
// MARK: - Logger Extension

public enum LogLevel: String, Codable {
  case debug, info, warning, propertyWarning, error
}

public func apiLog(_ level: LogLevel, _ message: String, _ key: String = "") {
  switch level {
  case .debug: Task { await ApiLog.shared.debug(message) }
  case .info: Task { await ApiLog.shared.info(message) }
  case .warning:  Task { await ApiLog.shared.warning(message) }
  case .propertyWarning: Task { await ApiLog.shared.propertyWarning(message, key) }
  case .error: Task { await ApiLog.shared.error(message) }
  }
}

extension Notification.Name {
  public static let logAlertWarning = Notification.Name("LogAlertWarning")
  public static let logAlertError = Notification.Name("LogAlertError")
}

public actor ApiLog: LoggingActor {
  private let _logger: Logger

  private var _messageIssues: [String: String] = [:]
    
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
  
  public func propertyWarning(_ message: String, _ key: String) async {
    _messageIssues[key] = message
    _logger.warning("\(message)")
    NotificationCenter.default.post(
      name: Notification.Name.logAlertWarning,
      object: AlertInfo("A Property Warning has been logged", message)
    )
  }

  public func error(_ message: String) async {
    _logger.error("\(message)")
    NotificationCenter.default.post(
      name: Notification.Name.logAlertError,
      object: AlertInfo("An Error has been logged", message)
    )
  }
  
  public func fetchIssues() -> [String: String] {
    _messageIssues
  }
}

//extension ApiLog {
//  public static func debug(_ message: String) async {
//    await shared.debug(message)
//  }
//  public static func info(_ message: String) async {
//    await shared.info(message)
//  }
//  public static func warning(_ message: String) async {
//    await shared.warning(message)
//  }
//  public static func propertyWarning(_ message: String, _ key: String) async {
//    await shared.propertyWarning(key, message)
//  }
//  public static func error(_ message: String) async {
//    await shared.error(message)
//  }
//}


public protocol LoggingActor {
  func debug(_ message: String) async
  func info(_ message: String) async
  func warning(_ message: String) async
  func propertyWarning(_ message: String, _ key: String) async
  func error(_ message: String) async
}
