import VRMKit
import Foundation

extension VRMError {
    static func _notSupported(_ message: @autoclosure () -> String,
                              file: StaticString = #file,
                              function: StaticString = #function,
                              line: UInt = #line) -> VRMError {
        return .notSupported("\(function)@\(file)[\(line)]: \(message())")
    }

    static func _dataInconsistent(_ message: @autoclosure () -> String,
                                  file: StaticString = #file,
                                  function: StaticString = #function,
                                  line: UInt = #line) -> VRMError {
        return .dataInconsistent("\(function)@\(file)[\(line)]: \(message())")
    }
}
