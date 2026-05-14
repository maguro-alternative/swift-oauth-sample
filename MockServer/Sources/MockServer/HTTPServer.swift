import Foundation
import Network

// MARK: - Request / Response

struct HTTPRequest {
    enum Method: String { case GET, POST, unknown }

    let method: Method
    let path: String
    let query: [String: String]
    let body: String

    init?(data: Data) {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }

        method = Method(rawValue: parts[0]) ?? .unknown

        let fullPath = parts[1]
        if let qIdx = fullPath.firstIndex(of: "?") {
            path = String(fullPath[..<qIdx])
            let qs = String(fullPath[fullPath.index(after: qIdx)...])
            query = Self.parseQuery(qs)
        } else {
            path = fullPath
            query = [:]
        }

        // ヘッダとボディを分割（空行で区切られる）
        if let sep = raw.range(of: "\r\n\r\n") {
            body = String(raw[sep.upperBound...])
        } else {
            body = ""
        }
    }

    static func parseQuery(_ qs: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in qs.components(separatedBy: "&") {
            let kv = pair.components(separatedBy: "=")
            guard kv.count == 2 else { continue }
            let key = kv[0].removingPercentEncoding ?? kv[0]
            let val = kv[1].removingPercentEncoding ?? kv[1]
            result[key] = val
        }
        return result
    }
}

struct HTTPResponse {
    let status: Int
    let headers: [String: String]
    let body: String

    static func ok(html: String) -> HTTPResponse {
        HTTPResponse(
            status: 200,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            body: html
        )
    }

    static func redirect(to location: String) -> HTTPResponse {
        HTTPResponse(
            status: 302,
            headers: ["Location": location],
            body: ""
        )
    }

    static func notFound() -> HTTPResponse {
        HTTPResponse(status: 404, headers: [:], body: "Not Found")
    }

    func serialize() -> Data {
        let statusText = status == 200 ? "OK" : status == 302 ? "Found" : "Not Found"
        var raw = "HTTP/1.1 \(status) \(statusText)\r\n"
        raw += "Connection: close\r\n"
        if !body.isEmpty {
            raw += "Content-Length: \(body.utf8.count)\r\n"
        }
        for (k, v) in headers {
            raw += "\(k): \(v)\r\n"
        }
        raw += "\r\n"
        raw += body
        return raw.data(using: .utf8)!
    }
}

// MARK: - Server

final class HTTPServer {
    private let listener: NWListener
    private let handler: (HTTPRequest) -> HTTPResponse
    private let queue = DispatchQueue(label: "http-server", attributes: .concurrent)

    init(port: UInt16, handler: @escaping (HTTPRequest) -> HTTPResponse) throws {
        self.handler = handler
        listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
    }

    func start() {
        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        listener.stateUpdateHandler = { state in
            if case .failed(let err) = state {
                print("[server] error: \(err)")
            }
        }
        listener.start(queue: queue)
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, let data, !data.isEmpty else { return }
            guard let req = HTTPRequest(data: data) else { return }
            let res = self.handler(req)
            conn.send(content: res.serialize(), completion: .contentProcessed { _ in
                conn.cancel()
            })
        }
    }
}
