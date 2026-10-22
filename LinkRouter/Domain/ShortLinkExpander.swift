import Foundation

struct ShortLinkExpander {
    static let hosts: Set<String> = [
        "t.co", "bit.ly", "bitly.com", "buff.ly", "lnkd.in", "ow.ly", "tinyurl.com",
        "goo.gl", "rebrand.ly", "is.gd", "trib.al", "dlvr.it", "amzn.to", "amzn.eu",
        "tiny.cc", "shorturl.at", "cutt.ly", "t.ly", "s.id"
    ]

    private let session: URLSession
    private let timeout: TimeInterval

    init(session: URLSession? = nil, timeout: TimeInterval = 2.5) {
        self.timeout = timeout
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpCookieStorage = nil
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout
            self.session = URLSession(configuration: configuration)
        }
    }

    static func isShortLink(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return hosts.contains(host)
    }

    func expand(_ url: URL) async -> URL {
        guard Self.isHTTP(url), Self.isShortLink(url) else { return url }
        let deadline = Date().addingTimeInterval(timeout)
        do {
            let head = try await perform(url, method: "HEAD", deadline: deadline)
            if head.statusCode == 403 || head.statusCode == 405 || head.redirectCount == 0 {
                let get = try await perform(url, method: "GET", deadline: deadline)
                guard get.redirectCount > 0, let target = get.redirectTarget, Self.isHTTP(target) else {
                    return url
                }
                return target
            }
            guard let target = head.redirectTarget, Self.isHTTP(target) else { return url }
            return target
        } catch {
            return url
        }
    }

    private func perform(
        _ url: URL,
        method: String,
        deadline: Date
    ) async throws -> RedirectResult {
        var request = URLRequest(url: url, timeoutInterval: deadline.timeIntervalSinceNow)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        var redirectCount = 0
        while true {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { throw URLError(.timedOut) }
            request.timeoutInterval = remaining
            let delegate = RedirectDelegate(maximumShortHops: 5)
            let (_, response) = try await session.data(for: request, delegate: delegate)
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if delegate.redirectCount > 0 {
                return RedirectResult(
                    statusCode: response.statusCode,
                    redirectCount: redirectCount + delegate.redirectCount,
                    redirectTarget: delegate.redirectTarget
                )
            }
            guard (300..<400).contains(response.statusCode),
                  let location = response.value(forHTTPHeaderField: "Location"),
                  let target = URL(string: location, relativeTo: response.url ?? request.url)?.absoluteURL
            else {
                return RedirectResult(
                    statusCode: response.statusCode,
                    redirectCount: redirectCount,
                    redirectTarget: nil
                )
            }
            redirectCount += 1
            guard redirectCount <= 5, Self.isShortLink(target) else {
                return RedirectResult(
                    statusCode: response.statusCode,
                    redirectCount: redirectCount,
                    redirectTarget: target
                )
            }
            request = URLRequest(url: target, timeoutInterval: deadline.timeIntervalSinceNow)
            request.httpMethod = method
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
    }

    private static func isHTTP(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

private struct RedirectResult {
    let statusCode: Int
    let redirectCount: Int
    let redirectTarget: URL?
}

private final class RedirectDelegate: NSObject, URLSessionTaskDelegate {
    private let maximumShortHops: Int
    private(set) var redirectCount = 0
    private(set) var redirectTarget: URL?

    init(maximumShortHops: Int) {
        self.maximumShortHops = maximumShortHops
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        redirectCount += 1
        redirectTarget = request.url
        guard redirectCount <= maximumShortHops,
              let target = request.url,
              ShortLinkExpander.isShortLink(target)
        else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
