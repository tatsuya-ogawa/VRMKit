import Foundation

public enum VRMError: Error {
    case notSupported(String)
    case notSupportedVersion(UInt32)
    case notSupportedChunkType(UInt32)
    case keyNotFound(String)
    case dataInconsistent(String)
}
