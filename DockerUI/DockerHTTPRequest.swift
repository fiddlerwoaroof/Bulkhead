//
//  DockerHTTPRequest.swift
//  DockerUI
//
//  Created by Edward Langley on 3/26/25.
//
import Foundation

struct DockerHTTPRequest {
    let path: String
    let method: String
    let body: Data?

    func rawData() -> Data {
        var request = "\(method) \(path) HTTP/1.1\r\n"
        request += "Host: docker\r\n"
        request += "Content-Type: application/json\r\n"
        if let body = body {
            request += "Content-Length: \(body.count)\r\n"
        }
        request += "\r\n"
        var data = Data(request.utf8)
        if let body = body {
            data.append(body)
        }
        return data
    }
}
