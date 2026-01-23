//
//  GlobalFunction.swift
//  VRMRealityKit
//
//  Created by Tatsuya Tanaka on 20180911.
//

import VRMKit
import Foundation

infix operator ???

func ???<T>(lhs: T?,
            error: @autoclosure () -> VRMError) throws -> T {
    guard let value = lhs else { throw error() }
    return value
}
