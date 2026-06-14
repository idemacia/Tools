import Foundation

public enum WidgetSnapshotFetcher {
    public static func fetchFromHost() async -> NoteSnapshot? {
        guard let url = URL(string: "http://127.0.0.1:\(AppConstants.widgetSnapshotPort)/snapshot") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return try JSONDecoder().decode(NoteSnapshot.self, from: data)
        } catch {
            return nil
        }
    }
}
