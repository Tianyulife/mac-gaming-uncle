import Foundation

/// A response may update the UI only if it belongs to the active search.
public struct SteamStoreSearchState: Sendable, Equatable {
    public enum Phase: Sendable, Equatable { case idle, waiting, loading, results, empty, failed(String) }
    public private(set) var query = ""
    public private(set) var phase: Phase = .idle
    public private(set) var results: [SteamStoreItem] = []
    private var requestID = UUID()
    public init() {}
    public var isLoading: Bool { phase == .loading }
    public var completed: Bool { phase == .results || phase == .empty }
    public var error: String? { if case .failed(let message) = phase { message } else { nil } }

    public mutating func reset(_ query: String) {
        requestID = UUID()
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        phase = self.query.count < 2 ? .idle : .waiting
        results = []
    }
    public mutating func begin(_ query: String) -> UUID {
        reset(query)
        phase = .loading
        return requestID
    }
    public mutating func complete(_ items: [SteamStoreItem], requestID: UUID) {
        guard self.requestID == requestID, phase == .loading else { return }
        results = items
        phase = items.isEmpty ? .empty : .results
    }
    public mutating func fail(_ message: String, requestID: UUID) {
        guard self.requestID == requestID, phase == .loading else { return }
        phase = .failed(message)
    }
}
