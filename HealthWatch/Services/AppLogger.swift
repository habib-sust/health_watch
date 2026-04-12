import os

extension Logger {
    private static let subsystem = "com.company.healthwatch"

    static let provisioning = Logger(subsystem: subsystem, category: "provisioning")
    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let dashboard = Logger(subsystem: subsystem, category: "dashboard")
    static let alerts = Logger(subsystem: subsystem, category: "alerts")
    static let qrScanner = Logger(subsystem: subsystem, category: "qrScanner")
}
