//
//  GLTF+.swift
//  VRMRealityKit
//
//  Created by Tatsuya Ogawa on 2026/01/22.
//

import VRMKit

protocol GLTFTextureInfoProtocol {
    var index: Int { get }
    var texCoord: Int { get }
}

extension GLTF.TextureInfo: GLTFTextureInfoProtocol {}
extension GLTF.Material.NormalTextureInfo: GLTFTextureInfoProtocol {}
extension GLTF.Material.OcclusionTextureInfo: GLTFTextureInfoProtocol {}
