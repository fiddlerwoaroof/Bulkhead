//
//  DockerExecutor.swift
//  DockerUI
//
//  Created by Edward Langley on 3/26/25.
//


import SwiftUI
import Foundation

class DockerExecutor {
    let socketPath: String

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    func makeRequest(path: String, method: String = "GET", body: Data? = nil) throws -> Data {
        let socket = try SocketConnection(path: URL(fileURLWithPath: socketPath))
        let request = DockerHTTPRequest(path: path, method: method, body: body)
        let requestData = request.rawData()
        LogManager.shared.append("Request: \(String(data: requestData, encoding: .utf8) ?? "<invalid>")")

        try socket.write(requestData)
        let response = try socket.readResponse()
        LogManager.shared.append("Raw Response: \(String(data: response, encoding: .utf8) ?? "<binary>")")

        guard let range = response.range(of: "\r\n\r\n".data(using: .utf8)!) else {
            throw NSError(domain: "DockerExecutor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Malformed HTTP response"])
        }

        let body = response[range.upperBound...]
        LogManager.shared.append("Parsed Body: \(String(data: body, encoding: .utf8) ?? "<binary>")")
        return Data(body)
    }

    func listContainers() throws -> [DockerContainer] {
        let data = try makeRequest(path: "/v1.41/containers/json?all=true")
        return try JSONDecoder().decode([DockerContainer].self, from: data)
    }

    func startContainer(id: String) throws {
        _ = try makeRequest(path: "/v1.41/containers/\(id)/start", method: "POST")
    }

    func stopContainer(id: String) throws {
        _ = try makeRequest(path: "/v1.41/containers/\(id)/stop", method: "POST")
    }
}
