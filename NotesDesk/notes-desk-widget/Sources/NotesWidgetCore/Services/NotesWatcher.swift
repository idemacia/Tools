import CoreServices
import Foundation

public final class NotesWatcher {
    private var stream: FSEventStreamRef?
    private var debounceWorkItem: DispatchWorkItem?
    private var onChange: (() -> Void)?
    private let debounceInterval: TimeInterval = 0.5
    private let queue = DispatchQueue(label: "com.notesdesk.widget.notes-watcher", qos: .utility)

    private let notesDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.com.apple.notes", isDirectory: true)
    }()

    public init() {}

    public func start(onChange: @escaping () -> Void) {
        stop()
        self.onChange = onChange

        guard FileManager.default.fileExists(atPath: notesDirectory.path) else {
            return
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)

        guard let stream = FSEventStreamCreate(
            nil,
            { _, clientInfo, _, _, _, _ in
                guard let clientInfo else { return }
                let watcher = Unmanaged<NotesWatcher>.fromOpaque(clientInfo).takeUnretainedValue()
                watcher.scheduleRefresh()
            },
            &context,
            [notesDirectory.path as CFString] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            flags
        ) else {
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    public func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        onChange = nil

        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    private func scheduleRefresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.onChange?()
            }
            self.debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + self.debounceInterval, execute: workItem)
        }
    }

    deinit {
        stop()
    }
}
