//
//  Collection+.swift
//  VRMRealityKit
//
//  Created by Tatsuya Tanaka on 20180911.
//

import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        return startIndex <= index && index < endIndex ? self[index] : nil
    }
}
