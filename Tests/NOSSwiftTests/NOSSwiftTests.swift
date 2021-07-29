import XCTest
import CryptoKit
import OpenCombine
@testable import NOSSwift

final class NOSSwiftTests: XCTestCase {
    var cancelBags: Set<AnyCancellable> = []
    let env = ProcessInfo.processInfo.environment
    var accessKey: String { env["accessKey"]! }
    var accessSecret: String { env["accessSecret"]! }
    var endpoint: String { env["endpoint"]! }
    var defaultBucket: String { env["defaultBucket"]! }

    override class func setUp() {
        super.setUp()
        let env = ProcessInfo.processInfo.environment
        let accessKey = env["accessKey"]!
        let accessSecret = env["accessSecret"]!
        let endpoint = env["endpoint"]!
        let defaultBucket = env["defaultBucket"]!
        NOS.initSDK(NOS.Config(accessKey: accessKey, accessSecret: accessSecret, endpoint: endpoint, defaultBucket: defaultBucket))
    }

    func testResourceStr() {
        let expect = "/foo/foo%2Fbar.zip"
        let resource = NOS.ResourceObject(bucket: "foo", objectKey: "foo/bar.zip")
        assert(resource.toString() == expect)
    }
    
    func testMD5() {
        let expect = "827ccb0eea8a706c4c34a16891f84e7b"
        assert(expect == NOS.md5("12345"))
    }
    
    func testSHA256() {
        let expect = "JhXiJW6pEnNkjvhRugZlq8uCpspzrieBLZBAI/8z4iE="
        let raw = "PUT\n827ccb0eea8a706c4c34a16891f84e7b\napplication/zip\nWed, 28 Jul 2021 08:38:54 GMT\n/foo/foo%2Fbar.zip"
        assert(expect == NOS.sha256(salt: "123123", data: raw))
    }

    func testDateFormatter() {
        let raw = "Wed, 28 Jul 2021 07:48:52"
        let expect = raw + " GMT"
        let date = NOS.dateFrom(raw)!
        let str = NOS.formatDate(date)
        assert(expect == str)
    }
    
    func testNormalizeHeaders() {
        let dateRaw = "Wed, 28 Jul 2021 08:38:54"
        let header: [String : Any] = [
            "Content-Type": "application/octet-stream",
            "Date": "\(dateRaw) GMT",
            "Content-MD5": "827ccb0eea8a706c4c34a16891f84e7b",
            "Content-Length": 5
        ]

        let expect: [String : Any] = [
            "content-type": "application/octet-stream",
            "date": "\(dateRaw) GMT",
            "content-md5": "827ccb0eea8a706c4c34a16891f84e7b",
            "content-length": 5
        ]
        
        let result = NOS.normalizeHeaders(header)
        result.forEach { kv in
            if let value = expect[kv.key] as? String, let expect = kv.value as? String {
                assert(value == expect)
            } else if let value = expect[kv.key] as? Int, let expect = kv.value as? Int {
                assert(value == expect)
            } else {
                assert(false)
            }
        }
    }
    
    func testSignature() {
        let dateRaw = "Wed, 28 Jul 2021 08:38:54"
        let expect = "JhXiJW6pEnNkjvhRugZlq8uCpspzrieBLZBAI/8z4iE="
        let headers = [
            "content-type": "application/zip",
            "date": NOS.dateFrom(dateRaw)!,
            "content-md5": "827ccb0eea8a706c4c34a16891f84e7b",
            "content-length": 5
        ] as [String : Any]
        let sign = NOS.signature(secretKey: "123123", method: "PUT", headers: headers, resource: NOS.ResourceObject(bucket: "foo", objectKey: "foo/bar.zip"))
        XCTAssert(sign == expect)
    }
    
    func testResourceURL() {
        let name = "text.txt"
        let target = "\(endpoint.hasSuffix("/") ? endpoint : (endpoint + "/"))\(defaultBucket)/\(name)"
        assert(NOS.resourceURL(for: name) == URL(string: target)!)
    }
    
    func testUpload() {
        asyncTest { e in
            let hello = "hello world".data(using: .utf8)!
            NOS.upload(data: hello, name: "hello.text").sink { re in
                print(re)
                e.fulfill()
            } receiveValue: { info in
                print(info)
            }.store(in: &cancelBags)
        }
    }
}

extension XCTestCase {
    func asyncTest(timeout: TimeInterval = 30, block: (XCTestExpectation) -> ()) {
        let expectation: XCTestExpectation = self.expectation(description: "❌:Timeout")
        block(expectation)
        self.waitForExpectations(timeout: timeout) { (error) in
            if let err = error {
                XCTFail("time out: \(err)")
            } else {
                XCTAssert(true, "success")
            }
        }
    }
}
