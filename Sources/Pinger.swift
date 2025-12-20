//
//  Pinger.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 12/14/16.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import SwiftUI

/// Pinger implementation
///
/// Generates "ping" messages every `pingInterval` second(s).
///
/// The timer is scheduled on a private dispatch queue and is safely managed within the actor context.
/// When the Pinger instance is deinitialized, the timer is cancelled and its event handler cleared to prevent any further executions.
/// This ensures proper cleanup and prevents potential retain cycles or timer leaks.
///
@MainActor
public final class Pinger {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Creates a new Pinger instance
  /// - Parameters:
  ///   - pingInterval: The interval in seconds between each "ping" message (default 1)
  ///   - apiModel: The ApiModel instance used to send "ping" messages
  public init(pingInterval: Int = 1, _ apiModel: ApiModel) {
    self.apiModel = apiModel
    self.pingInterval = pingInterval

    // create the timer's dispatch source on the ping queue
    self.pingTimer = DispatchSource.makeTimerSource(queue: pingQueue)

    // Setup the timer to fire immediately and repeat every pingInterval seconds
    pingTimer.schedule(deadline: DispatchTime.now(), repeating: .seconds(pingInterval), leeway: .milliseconds(100))

    // set the event handler to send "ping" messages asynchronously on the main actor
    pingTimer.setEventHandler { [weak self] in
        guard let self = self else { return }
        Task { self.apiModel.sendTcp("ping") }
    }

    // start the timer
    pingTimer.resume()
  }

  deinit {
    // Cancel the timer and clear the event handler to prevent any further events and potential retain cycles
    pingTimer.setEventHandler {}
    pingTimer.cancel()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  private let apiModel: ApiModel
  private let pingQueue = DispatchQueue(label: "PingQ")
  private let pingTimer: DispatchSourceTimer
  private let pingInterval: Int
}

