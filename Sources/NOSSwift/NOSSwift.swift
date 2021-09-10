import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import OpenCombine
import OpenCombineFoundation
import Crypto

public final class NOS {
    static let shared = NOS()
    let session = URLSession.shared
    var config: Config = .empty
    lazy var dateFormatter: DateFormatter = {
        let dft = DateFormatter()
        dft.dateFormat = "E, d MMM yyyy HH:mm:ss"
        dft.locale = Locale(identifier: "en_US")
        dft.timeZone = TimeZone(secondsFromGMT: 0)
        return dft
    }()
    
    private init() {}

    public static func initSDK(_ config: Config) {
        shared.config = config
    }
    
    public static func resourceURL(for name: String) -> URL {
        var u = URL(string: shared.config.host)!
        if shared.config.isSubDomain == false {
            u.appendPathComponent(shared.config.defaultBucket)
        }
        u.appendPathComponent(name)
        return u
    }
    
    public static func upload(data: Data, name: String) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        let method = "PUT"
        let (header, res) = constructHeader(for: name, contentLength: data.count, method: method)
        let url = constructURL(res: res)
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        header.forEach { kv in
            req.addValue(kv.value, forHTTPHeaderField: kv.key)
        }
        req.httpBody = data
        req = constructHost(req, res: res, host: url.host!)
        return shared.session.ocombine.dataTaskPublisher(for: req).eraseToAnyPublisher()
    }
    
    public static func delete(name: String) -> AnyPublisher<(data: Data, response: URLResponse), URLError>  {
        let method = "DELETE"
        let (header, res) = constructHeader(for: name, method: method)
        let url = constructURL(res: res)
        var req = URLRequest(url: url)
        req.httpMethod = method
        header.forEach { kv in
            req.addValue(kv.value, forHTTPHeaderField: kv.key)
        }
        req = constructHost(req, res: res, host: url.host!)
        return shared.session.ocombine.dataTaskPublisher(for: req).eraseToAnyPublisher()
    }
    
    static func constructHost(_ req: URLRequest, res: ResourceObject, host: String) -> URLRequest {
        var re = req
        if shared.config.isSubDomain {
            re.addValue(host, forHTTPHeaderField: "host")
        } else {
            re.addValue("\(res.bucket).\(host)", forHTTPHeaderField: "host")
        }
        return re
    }
    
    static func constructURL(res: ResourceObject) -> URL {
        let u = URL(string: shared.config.endpoint)!
        let realEndPoint: String = {
            if shared.config.isSubDomain {
                return "\(u.scheme!)://\(shared.config.defaultBucket).\(u.host!)"
            } else {
                return shared.config.endpoint
            }
        }()
        var url = URL(string: realEndPoint)!
        url.appendPathComponent(res.uri())
        return url
    }
    
    static func constructHeader(for name: String, contentLength: Int? = nil, method: String) -> ([String : String], ResourceObject) {
        var header: [String: String] = [:]
        header["date"] = formatDate()
        if let length = contentLength {
            header["content-length"] = "\(length)"
        }
        let res = ResourceObject(bucket: shared.config.defaultBucket, objectKey: name)
        let sign = signature(secretKey: shared.config.accessSecret, method: method, headers: header, resource: res)
        header["authorization"] = "NOS \(shared.config.accessKey):\(sign)"
        return (header, res)
    }
    
    static func sha256(salt: String, data: String) -> String {
        let k = SymmetricKey(data: salt.data(using: .utf8)!)
        let signature = HMAC<SHA256>.authenticationCode(for: data.data(using: .utf8)!, using: k)
        return Data(signature).base64EncodedString()
    }
    
    static func md5(_ data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)
        let md5 = digest.map { String(format: "%02hhx", $0)}.joined()
        return md5
    }
    
    static func md5(_ str: String) -> String {
        return md5(str.data(using: .utf8)!)
    }

    static func formatDate(_ date: Date? = nil) -> String {
        return shared.dateFormatter.string(from: date ?? Date()) + " GMT"
    }
    
    static func dateFrom(_ str: String) -> Date? {
        return shared.dateFormatter.date(from: str)
    }
    
    static func normalizeHeaders(_ headers: [String : Any]) -> [String : Any] {
        var p: [String : Any] = [:]
        headers.forEach { kv in
            p[kv.key.lowercased()] = kv.value
        }
        return p
    }
    
    static func signature(secretKey: String, method: String, headers: [String : Any], resource: ResourceObject) -> String {
        var h = headers
        if h["date"] == nil {
            h["date"] = formatDate()
        } else if let date = h["date"] as? Date {
            h["date"] = formatDate(date)
        }
        h = normalizeHeaders(h)
        
        let contentMD5: String = (h["content-md5"] as? String) ?? ""
        let contentType: String = (h["content-type"] as? String) ?? ""
        let date = h["date"] as! String
        let resourceStr = resource.toString().trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [
            method.uppercased(),
            contentMD5,
            contentType,
            date,
            resourceStr
        ].joined(separator: "\n")
        return sha256(salt: secretKey, data: parts)
    }
}
extension NOS {
    
    public struct ResourceObject {
        public let bucket: String
        public let objectKey: String
        public init(bucket:String, objectKey:String) {
            self.bucket = bucket
            self.objectKey = objectKey
        }
        
        func toString() -> String {
            return "/\(bucket)/\(objectKey.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? objectKey)"
        }
        
        func uri() -> String {
            return "\(objectKey)"
        }
    }
    
    public struct Config {
        public let accessKey: String
        public let accessSecret: String
        public let endpoint: String
        public let defaultBucket: String
        public let cdnDomain: String?
        public var host: String { cdnDomain ?? endpoint }
        public var isSubDomain: Bool
        
        public init(accessKey: String, accessSecret: String, endpoint: String, defaultBucket: String, cdnDomain: String? = nil, isSubDomain: Bool = false) {
            self.accessKey = accessKey
            self.accessSecret = accessSecret
            self.endpoint = endpoint
            self.defaultBucket = defaultBucket
            self.cdnDomain = cdnDomain
            self.isSubDomain = isSubDomain
        }
        
        static let empty = Config(accessKey: "", accessSecret: "", endpoint: "", defaultBucket: "")
    }
}
