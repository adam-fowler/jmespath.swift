# JMESPath for Swift

Swift implementation of [JMESPath](https://jmespath.org/), a query language for JSON.

## Usage

Below is a simple example of usage.

```swift
import JMESPath

let expression = try Expression.compile("a.b")
let result = try expression.search(json: #"{"a": {"b": "hello"}}"#, as: String.self)
assert(String == "hello")
```

JMESPath will also use Mirror reflection to search objects already in memory
```swift
struct TestObject {
  struct TestSubObject {
      let b: [String]
  }
  let a: TestSubObject
}
let expression = try Expression.compile("a.b[1]")
let test = TestObject(a: .init(b: ["hello", "world!"]))
let result = try expression.search(test, as: String.self)
assert(result == "world!")
```
