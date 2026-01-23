import XCTest
import VRMKit

class BinaryGLTFTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    func testLoadVRM() {
        let binaryGltf = try! BinaryGLTF(data: Resources.aliciaSolid.data)
        let json = binaryGltf.jsonData
        XCTAssertEqual(json.asset.generator, "UniGLTF")
        XCTAssertEqual(json.asset.version, "2.0")
    }
    
}
