//
//  SocketConnection.swift
//  DockerUI
//
//  Created by Edward Langley on 3/26/25.
//
import Foundation

class SocketConnection {
    private let socket: Int32
    
    init(path: URL) throws {
        socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let socketPath = path.path
        _ = withUnsafeMutablePointer(to: &addr.sun_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: 104) { ptr in
                strncpy(ptr, socketPath, 104)
            }
        }
        let size = socklen_t(MemoryLayout.size(ofValue: addr))
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socket, $0, size)
            }
        }
        guard result >= 0 else {
            close(socket)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
    }
    
    func write(_ data: Data) throws {
        let result = data.withUnsafeBytes {
            Darwin.send(socket, $0.baseAddress!, data.count, 0)
        }
        guard result >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
    }
    
    func readResponse(timeout: TimeInterval = 5.0) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var response = Data()
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            let bytesRead = Darwin.recv(socket, &buffer, buffer.count, 0)
            if bytesRead > 0 {
                response.append(buffer, count: bytesRead)
                if let string = String(data: response, encoding: .utf8), string.contains("\r\n\r\n") {
                    break
                }
            } else if bytesRead == 0 {
                break
            } else {
                if errno == EWOULDBLOCK || errno == EAGAIN {
                    usleep(100_000) // wait briefly before retry
                    continue
                } else {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
                }
            }
        }
        
        guard let headerEndRange = response.range(of: "\r\n\r\n".data(using: .utf8)!) else {
            throw NSError(domain: "SocketConnection", code: -1, userInfo: [NSLocalizedDescriptionKey: "Malformed HTTP response"])
        }

        let headerData = response[..<headerEndRange.lowerBound]
        let bodyData = response[headerEndRange.upperBound...]
        let headersString = String(data: headerData, encoding: .utf8) ?? ""

        LogManager.shared.append("Response Headers:\n\(headersString)")
        
        if headersString.lowercased().contains("transfer-encoding: chunked") {
            return try dechunk(bodyData)
        } else {
            return Data(bodyData)
        }
    }
    
    private func dechunk(_ data: Data) throws -> Data {
        var result = Data()
        var currentIndex = data.startIndex

        while currentIndex < data.endIndex {
            guard let crlfRange = data[currentIndex...].range(of: "\r\n".data(using: .utf8)!) else {
                break
            }

            let sizeLineData = data[currentIndex..<crlfRange.lowerBound]
            guard let sizeLine = String(data: sizeLineData, encoding: .utf8),
                  let chunkSize = Int(sizeLine, radix: 16), chunkSize > 0 else {
                break
            }

            let chunkStart = crlfRange.upperBound
            let chunkEnd = data.index(chunkStart, offsetBy: chunkSize, limitedBy: data.endIndex) ?? data.endIndex

            if chunkEnd > data.endIndex { break }
            result.append(data[chunkStart..<chunkEnd])

            currentIndex = chunkEnd
            if let nextCRLF = data[currentIndex...].range(of: "\r\n".data(using: .utf8)!) {
                currentIndex = nextCRLF.upperBound
            } else {
                break
            }
        }

        return result
    }

    
    deinit {
        close(socket)
    }
}
