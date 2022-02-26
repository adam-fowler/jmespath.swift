// Sendable support 

#if compiler(>=5.6)
public typealias JMESSendable = Sendable
#else
public typealias JMESSendable = Any
#endif