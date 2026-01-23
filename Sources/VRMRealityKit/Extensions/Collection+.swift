//
//  Collection+.swift
//  VRMRealityKit
//
//  Created by Tatsuya Ogawa on 2026/01/22.
//

import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        return startIndex <= index && index < endIndex ? self[index] : nil
    }
}
