//
//  MeterStream.swift
//  ApiPackage
//
//  Created by Douglas Adams on 3/4/25.
//

import Foundation

final public class MeterStream {
  
  public init(_ id: UInt32, apiModel: ApiModel) {
    self.id = id
    api = apiModel
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Properties
  
  public var id: UInt32
  
  private let api: ApiModel
  
  let kDbDbmDbfsSwrDenom   : Float = 128.0  // denominator for Db, Dbm, Dbfs, Swr
  let kDegDenom            : Float = 64.0   // denominator for Degc, Degf

  // ------------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Process the Meter Vita struct
  ///
  ///   Executes on the streamQ
  ///      The payload of the incoming Vita struct is converted to Meter values
  ///      Called by Radio
  ///      Sends meterUpdated notifications
  ///
  /// - Parameters:
  ///   - vita:        a Vita struct
  ///
  public func streamProcessor(_ vita: Vita) {
    var meterIds = [UInt16]()
    
    // NOTE:  there is a bug in the Radio (as of v2.2.8) that sends
    //        multiple copies of meters, this code ignores the duplicates
    
    vita.payloadData.withUnsafeBytes { (payloadPtr) in
      // four bytes per Meter
      let numberOfMeters = Int(vita.payloadSize / 4)
      
      // pointer to the first Meter number / Meter value pair
      let ptr16 = payloadPtr.bindMemory(to: UInt16.self)
      
      // for each meter in the Meters packet
      for i in 0..<numberOfMeters {
        // get the Meter id and the Meter value
        let id: UInt16 = CFSwapInt16BigToHost(ptr16[2 * i])
        let value: UInt16 = CFSwapInt16BigToHost(ptr16[(2 * i) + 1])
        
        // is this a duplicate?
        if !meterIds.contains(id) {
          // NO, add it to the list
          meterIds.append(id)
          
          Task {
            // find the meter (if present) & update it
            if let meter = await api.meters.first(where: {$0.id == id}) {
              let newValue = Int16(bitPattern: value)
//              let previousValue = meter.value
              
              // check for unknown Units
              guard let token = await MeterUnits(rawValue: meter.units) else {
                //      // log it and ignore it
                //      _log("Meter \(desc) \(description) \(group) \(name) \(source): unknown units - \(units))", .warning, #function, #file, #line)
                return
              }
              var adjNewValue: Float = 0.0
              switch token {
                
              case .db, .dbm, .dbfs, .swr:
                adjNewValue = Float(exactly: newValue)! / kDbDbmDbfsSwrDenom
                
              case .volts, .amps:
                var denom :Float = 256.0
                adjNewValue = Float(exactly: newValue)! / denom
                
              case .degc, .degf:
                adjNewValue = Float(exactly: newValue)! / kDegDenom
                
              case .rpm, .watts, .percent, .none:
                adjNewValue = Float(exactly: newValue)!
              }
              // did it change?
//              if adjNewValue != previousValue {
              await meter.setValue(adjNewValue)
//              }
            }
          }
        }
      }
    }
  }

}
