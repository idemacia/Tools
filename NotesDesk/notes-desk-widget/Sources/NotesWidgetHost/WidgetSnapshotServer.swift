import Foundation
import Network
import NotesWidgetCore

final class WidgetSnapshotServer {
    static let shared = WidgetSnapshotServer()

    private var listener: NWListener?
    private let lock = NSLock()
    private var snapshotData = Data()

    func start() {
        guard listener == nil else { return }

        if let cached = SharedStore.loadCurrentWidgetSnapshot(),
           let data = try? JSONEncoder().encode(cached) {
            lock.lock()
            snapshotData = data
            lock.unlock()
        }

        let port = NWEndpoint.Port(rawValue: AppConstants.widgetSnapshotPort)!
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback

        do {
            let listener = try NWListener(using: params, on: port)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    print("WidgetSnapshotServer 监听失败: \(error)")
                }
            }
            listener.start(queue: .global(qos: .utility))
            self.listener = listener
            print("WidgetSnapshotServer 已启动: http://127.0.0.1:\(AppConstants.widgetSnapshotPort)/snapshot")
        } catch {
            print("WidgetSnapshotServer 启动失败: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    func update(_ snapshot: NoteSnapshot) {
        let data = (try? JSONEncoder().encode(snapshot)) ?? Data()
        lock.lock()
        snapshotData = data
        lock.unlock()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] _, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }

            self.lock.lock()
            let body = self.snapshotData
            self.lock.unlock()

            let header = """
            HTTP/1.1 200 OK\r
            Content-Type: application/json\r
            Content-Length: \(body.count)\r
            Connection: close\r
            \r

            """
            var response = Data(header.utf8)
            response.append(body)

            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
