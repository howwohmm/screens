import Foundation
import CryptoKit

// MARK: - Cache directory

private let cacheDir: URL = {
    let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".screens/cache/images", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}()

private func cachePath(for url: URL) -> URL {
    let key = SHA256.hash(data: Data(url.absoluteString.utf8))
        .map { String(format: "%02x", $0) }.joined()
    let rawExt = url.pathExtension.lowercased()
    let ext = ["jpg","jpeg","png","gif","webp","avif"].contains(rawExt) ? rawExt : "jpg"
    return cacheDir.appendingPathComponent("\(key).\(ext)")
}

// MARK: - Client

actor ArenaClient {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.are.na/v3")!

    init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "screens/1.0"]
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: Fetch channel

    func fetchChannel(slug: String) async throws -> [ArenaBlock] {
        var all: [ArenaBlock] = []
        var page = 1
        let perPage = 100

        while true {
            let comps = URLComponents(url: baseURL.appendingPathComponent("channels/\(slug)/contents"), resolvingAgainstBaseURL: false)!
                .with(queryItems: [
                    URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "per",  value: "\(perPage)")
                ])
            let (data, resp) = try await session.data(from: comps.url!)
            if let http = resp as? HTTPURLResponse {
                if http.statusCode == 404 { throw ArenaError.channelNotFound(slug) }
                if http.statusCode == 429 { throw ArenaError.rateLimited }
                guard http.statusCode == 200 else { throw ArenaError.httpError(http.statusCode) }
            }
            let decoded = try JSONDecoder().decode(ArenaChannelResponse.self, from: data)
            let items = decoded.items
            let blocks = items.compactMap { $0.toBlock(channelSlug: slug) }
            all.append(contentsOf: blocks)
            // Use total_pages / current_page from meta (more reliable than item count heuristic)
            let hasMore = decoded.meta?.hasMorePages ?? (items.count >= perPage)  // fallback if meta absent
            if !hasMore || items.isEmpty { break }
            page += 1
        }
        return all
    }

    func fetchAllChannels(slugs: [String]) async -> [ArenaBlock] {
        await withTaskGroup(of: [ArenaBlock].self) { group in
            for slug in slugs {
                group.addTask {
                    (try? await self.fetchChannel(slug: slug)) ?? []
                }
            }
            var result: [ArenaBlock] = []
            for await blocks in group { result.append(contentsOf: blocks) }
            return result
        }
    }

    // MARK: Image download

    func localImageURL(for block: ArenaBlock) async -> URL? {
        guard let remote = block.imageURL else { return nil }
        let local = cachePath(for: remote)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        do {
            let (tmp, resp) = try await session.download(from: remote)
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 { return nil }
            try? FileManager.default.removeItem(at: local)
            try FileManager.default.moveItem(at: tmp, to: local)
            return local
        } catch {
            return nil
        }
    }

    // MARK: Validate channel (for onboarding + settings)
    // Only fetches the channel metadata endpoint — fast even for huge channels.

    func validateChannel(slug: String) async throws -> (name: String, count: Int) {
        let comps = URLComponents(url: baseURL.appendingPathComponent("channels/\(slug)"), resolvingAgainstBaseURL: false)!
        let (data, resp) = try await session.data(from: comps.url!)
        if let http = resp as? HTTPURLResponse {
            if http.statusCode == 404 { throw ArenaError.channelNotFound(slug) }
            guard http.statusCode == 200 else { throw ArenaError.httpError(http.statusCode) }
        }
        struct ChannelInfo: Decodable {
            let title: String?
            let length: Int?
        }
        let info = try JSONDecoder().decode(ChannelInfo.self, from: data)
        return (name: info.title ?? slug, count: info.length ?? 0)
    }
}

// MARK: - URLComponents helper

private extension URLComponents {
    func with(queryItems: [URLQueryItem]) -> URLComponents {
        var copy = self
        copy.queryItems = queryItems
        return copy
    }
}

// MARK: - Errors

enum ArenaError: LocalizedError {
    case channelNotFound(String)
    case rateLimited
    case httpError(Int)
    case noInternet

    var errorDescription: String? {
        switch self {
        case .channelNotFound(let s): return "Channel '\(s)' not found. Check the slug and try again."
        case .rateLimited:            return "Are.na rate limit hit. Try again in a moment."
        case .httpError(let c):       return "Network error (\(c)). Check your connection."
        case .noInternet:             return "No internet connection."
        }
    }
}
