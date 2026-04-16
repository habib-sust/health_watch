import os

extension Logger {
    private nonisolated(unsafe) static let subsystem = "com.company.healthwatch.watch"

    nonisolated static let provisioning = Logger(subsystem: subsystem, category: "provisioning")
    nonisolated static let healthKit = Logger(subsystem: subsystem, category: "healthkit")
    nonisolated static let networking = Logger(subsystem: subsystem, category: "networking")
    nonisolated static let buffer = Logger(subsystem: subsystem, category: "buffer")
    nonisolated static let sync = Logger(subsystem: subsystem, category: "sync")
}
