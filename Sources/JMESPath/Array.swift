typealias JMESArray = [Any]

extension JMESArray {
    /// return if arrays are equal by converting entries to `JMESVariable`
    func equalTo(_ rhs: JMESArray) -> Bool {
        guard self.count == rhs.count else { return false }
        for i in 0..<self.count {
            guard JMESVariable(from: self[i]) == JMESVariable(from: rhs[i]) else {
                return false
            }
        }
        return true
    }
}

extension Array {
    /// calculate actual index. Negative indices read backwards from end of array
    func calculateIndex(_ index: Int) -> Int {
        if index >= 0 {
            return index
        } else {
            return count + index
        }
    }
}
