import Foundation

final class LogFetcher {
  private let executor: DockerExecutor

  init(executor: DockerExecutor) {
    self.executor = executor
  }

  /// Fetches logs from a container, auto-detecting whether to use multiplexed parsing or raw.
  func fetchLogs(for containerID: String, tail: Int = 100, stream: DockerLogStreamType = .stdout)
    throws -> [[UInt8]]
  {
    let isTTY = try executor.isTTYEnabled(forContainer: containerID)
    let data = try executor.getContainerLogs(id: containerID, tail: tail)

    if isTTY {
      let parser = DockerRawLogParser()
      return parser.append(data: data) + parser.flush()
    } else {
      let parser = DockerLogStreamParser()
      let lines = parser.append(data: data) + parser.flush()
      return lines.filter { $0.stream == stream }.map { $0.message }
    }
  }
}
