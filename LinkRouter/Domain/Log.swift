import os

enum Log {
    static let app = Logger(subsystem: "app.linkrouter", category: "app")
    static let routing = Logger(subsystem: "app.linkrouter", category: "routing")
}
