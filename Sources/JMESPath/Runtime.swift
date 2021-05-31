
class Runtime {
    init() {
        self.functions = [:]
        self.registerBuiltInFunctions()
    }

    func getFunction(_ name: String) -> Function.Type? {
        return self.functions[name]
    }

    func registerFunction(_ name: String, function: Function.Type) {
        self.functions[name] = function
    }

    func registerBuiltInFunctions() {
        self.registerFunction("abs", function: AbsFunction.self)
        self.registerFunction("avg", function: AvgFunction.self)
        self.registerFunction("ceil", function: CeilFunction.self)
        self.registerFunction("contains", function: ContainsFunction.self)
        self.registerFunction("ends_with", function: EndsWithFunction.self)
        self.registerFunction("floor", function: FloorFunction.self)
        self.registerFunction("join", function: JoinFunction.self)
        self.registerFunction("keys", function: KeysFunction.self)
        self.registerFunction("length", function: LengthFunction.self)
        self.registerFunction("map", function: MapFunction.self)
        self.registerFunction("max", function: MaxFunction.self)
        self.registerFunction("max_by", function: MaxByFunction.self)
        self.registerFunction("min", function: MinFunction.self)
        self.registerFunction("min_by", function: MinByFunction.self)
        self.registerFunction("merge", function: MergeFunction.self)
        self.registerFunction("not_null", function: NotNullFunction.self)
        self.registerFunction("reverse", function: ReverseFunction.self)
        self.registerFunction("sort", function: SortFunction.self)
        self.registerFunction("sort_by", function: SortByFunction.self)
        self.registerFunction("starts_with", function: StartsWithFunction.self)
        self.registerFunction("sum", function: SumFunction.self)
        self.registerFunction("to_array", function: ToArrayFunction.self)
        self.registerFunction("to_number", function: ToNumberFunction.self)
        self.registerFunction("to_string", function: ToStringFunction.self)
        self.registerFunction("type", function: TypeFunction.self)
        self.registerFunction("values", function: ValuesFunction.self)
    }

    var functions: [String: Function.Type]
}
