# JMESPath for Swift

Swift implementation of [JMESPath](https://jmespath.org/), a query language for JSON. This package is fully compliant with the [JMES Specification](https://jmespath.org/specification.html)

## Usage

Below is a simple example of usage.

```swift
import JMESPath

// compile query "a.b"
let expression = try JMESExpression.compile("a.b")
// use query to search json string
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
// compile query "a.b[1]"
let expression = try JMESExpression.compile("a.b[1]")
let test = TestObject(a: .init(b: ["hello", "world!"]))
// use query to search `test` object
let result = try expression.search(object: test, as: String.self)
assert(result == "world!")
```
