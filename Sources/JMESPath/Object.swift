/// JMES Object type
typealias JMESObject = [String: Any]

extension JMESObject {
    /// return if objects are equal by converting values to `JMESVariable`
    func equalTo(_ rhs: JMESObject) -> Bool {
        guard self.count == rhs.count else { return false }
        for element in self {
            guard let rhsValue = rhs[element.key],
                JMESVariable(from: rhsValue) == JMESVariable(from: element.value)
            else {
                return false
            }
        }
        return true
    }
}
