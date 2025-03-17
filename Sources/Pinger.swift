//
//  Pinger.swift
//  FlexApiFeature/Objects
//
//  Created by Douglas Adams on 12/14/16.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import SwiftUI

///  Pinger  implementation
///
///      generates "ping" messages every pingInterval second(s)
///
@MainActor
public final class Pinger {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(pingInterval: Int = 1, _ apiModel: ApiModel) {
    _apiModel = apiModel

    // create the timer's dispatch source
    _pingTimer = DispatchSource.makeTimerSource(queue: _pingQ)

    // Setup the timer
    _pingTimer.schedule(deadline: DispatchTime.now(), repeating: .seconds(pingInterval), leeway: .milliseconds(100))

    // set the event handler
    _pingTimer.setEventHandler(handler: { [self] in
        Task { _apiModel.sendTcp("ping") }
    })
    // start the timer
    _pingTimer.resume()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Properties
  
  private let _apiModel: ApiModel
  private let _pingQ = DispatchQueue(label: "PingQ")
  private let _pingTimer: DispatchSourceTimer!
}
