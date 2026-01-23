//
//  GlobalFunction.swift
//  VRMRealityKit
//
//  Created by Tatsuya Ogawa on 2026/01/22.
//

import VRMKit
import Foundation

infix operator ???

func ???<T>(lhs: T?,
            error: @autoclosure () -> VRMError) throws -> T {
    guard let value = lhs else { throw error() }
    return value
}
