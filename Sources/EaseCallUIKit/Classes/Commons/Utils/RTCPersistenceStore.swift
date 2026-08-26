import Foundation

struct RTCCredentialRecord: Codable, Equatable, Sendable {
    let appID: String
    let userID: String
    let uid: UInt32
    let token: String
    let expiration: Int64
    let generation: UInt64
}

final class RTCPersistenceStore {
    private struct Snapshot: Codable {
        var schemaVersion = 1
        var credentials: [String: RTCCredentialRecord] = [:]
        var relations: [String: [String: String]] = [:]
    }

    private enum Keys {
        static let snapshot = "com.easemob.callkit.rtc-persistence.v1"
    }

    private let queue = DispatchQueue(label: "com.easemob.callkit.rtc-persistence")
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var snapshot: Snapshot

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.snapshot),
           let decoded = try? decoder.decode(Snapshot.self, from: data),
           decoded.schemaVersion == 1 {
            snapshot = decoded
        } else {
            snapshot = Snapshot()
        }
    }

    func loadCredential(appID: String, userID: String) -> RTCCredentialRecord? {
        queue.sync {
            snapshot.credentials[credentialKey(appID: appID, userID: userID)]
        }
    }

    func loadRelations(appID: String) -> [UInt: String] {
        queue.sync {
            Dictionary(uniqueKeysWithValues: (snapshot.relations[appID] ?? [:]).compactMap { key, value in
                guard let uid = UInt(key), uid > 0, !value.isEmpty else { return nil }
                return (uid, value)
            })
        }
    }

    func saveCredential(_ record: RTCCredentialRecord) async {
        await enqueue {
            let key = self.credentialKey(appID: record.appID, userID: record.userID)
            if let current = self.snapshot.credentials[key], current.generation > record.generation { return }
            self.snapshot.credentials[key] = record
            self.persistSnapshot()
        }
    }

    func mergeRelations(_ relations: [UInt: String], appID: String) async {
        await enqueue {
            self.mergeRelationsOnQueue(relations, appID: appID)
        }
    }

    /// Submits a non-blocking relation merge. A later `flush()` is ordered after it.
    func scheduleMergeRelations(_ relations: [UInt: String], appID: String) {
        queue.async {
            self.mergeRelationsOnQueue(relations, appID: appID)
        }
    }

    func flush() async { await enqueue {} }

    func clear(appID: String? = nil, userID: String? = nil) async {
        await enqueue {
            if let appID = appID {
                self.snapshot.relations.removeValue(forKey: appID)
                self.snapshot.credentials = self.snapshot.credentials.filter { _, value in
                    value.appID != appID || (userID != nil && value.userID != userID)
                }
            } else {
                self.snapshot = Snapshot()
            }
            self.persistSnapshot()
        }
    }

    private func credentialKey(appID: String, userID: String) -> String {
        Data("\(appID)\u{0}\(userID)".utf8).base64EncodedString()
    }

    private func persistSnapshot() {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: Keys.snapshot)
    }

    private func mergeRelationsOnQueue(_ relations: [UInt: String], appID: String) {
        var current = snapshot.relations[appID] ?? [:]
        for (uid, userID) in relations where uid > 0 && !userID.isEmpty {
            current[String(uid)] = userID
        }
        snapshot.relations[appID] = current
        persistSnapshot()
    }

    private func enqueue(_ operation: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            queue.async {
                operation()
                continuation.resume()
            }
        }
    }
}
