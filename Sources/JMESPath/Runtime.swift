
class Runtime {

    init() {
        functions = [:]
        registerBuiltInFunctions()
    }

    func getFunction(_ name: String) -> Function.Type? {
        return self.functions[name]
    }

    func registerFunction(_ name: String, function: Function.Type) {
        functions[name] = function
    }

    func registerBuiltInFunctions() {
        registerFunction("abs", function: AbsFunction.self)
        registerFunction("avg", function: AvgFunction.self)
        registerFunction("ceil", function: CeilFunction.self)
        registerFunction("contains", function: ContainsFunction.self)
        registerFunction("ends_with", function: EndsWithFunction.self)
        registerFunction("floor", function: FloorFunction.self)
        registerFunction("join", function: JoinFunction.self)
        registerFunction("keys", function: KeysFunction.self)
        registerFunction("length", function: LengthFunction.self)
        registerFunction("map", function: MapFunction.self)
        registerFunction("max", function: MaxFunction.self)
        registerFunction("max_by", function: MaxByFunction.self)
        registerFunction("min", function: MinFunction.self)
        registerFunction("min_by", function: MinByFunction.self)
        registerFunction("merge", function: MergeFunction.self)
    }

    var functions: [String: Function.Type]
}
