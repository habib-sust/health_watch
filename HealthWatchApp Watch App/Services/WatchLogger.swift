import os

extension Logger {
    private static let subsystem = "com.company.healthwatch.watch"

    static let provisioning = Logger(subsystem: subsystem, category: "provisioning")
    static let healthKit = Logger(subsystem: subsystem, category: "healthkit")
    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let buffer = Logger(subsystem: subsystem, category: "buffer")
    static let sync = Logger(subsystem: subsystem, category: "sync")
}
