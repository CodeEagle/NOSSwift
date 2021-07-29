# NOSSwift

A description of this package.

# Usage
```swift
// init
NOS.initSDK(NOS.Config(accessKey: accessKey, accessSecret: accessSecret, endpoint: endpoint, defaultBucket: defaultBucket))

// upload
let hello = "hello world".data(using: .utf8)!
NOS.upload(data: hello, name: "hello.text").sink { re in
    print(re)
} receiveValue: { info in
    print(info)
}.store(in: &cancelBags)
```
