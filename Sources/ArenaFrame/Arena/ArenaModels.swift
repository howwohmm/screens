import Foundation

// MARK: - Block

struct ArenaBlock: Identifiable, Hashable {
    let id: Int
    let channelSlug: String
    let title: String
    let blockType: String      // "Image" | "Text" | "Link"
    let imageURL: URL?
    let imageWidth: Int?
    let imageHeight: Int?
    let textContent: String?   // markdown for Text blocks

    var isVisual: Bool { (blockType == "Image" || blockType == "Link") && imageURL != nil }
    var isText:   Bool { blockType == "Text" && !(textContent?.isEmpty ?? true) }
    var isRenderable: Bool { isVisual || isText }

    /// True if this image won't look pixelated on the given screen at maxUpscale.
    func isHQ(screenW: Double, screenH: Double, maxUpscale: Double) -> Bool {
        guard isVisual, maxUpscale > 0 else { return true }
        guard let w = imageWidth, let h = imageHeight, w > 0, h > 0 else { return true }
        let scale = min(screenW / Double(w), screenH / Double(h))
        return scale <= maxUpscale
    }

    var displayLabel: String {
        [channelSlug, title].filter { !$0.isEmpty }.joined(separator: "  ·  ")
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (l: ArenaBlock, r: ArenaBlock) -> Bool { l.id == r.id }
}

// MARK: - API response shapes

struct ArenaChannelResponse: Decodable {
    let data: [ArenaBlockDTO]?
    let contents: [ArenaBlockDTO]?   // legacy key
    let meta: ArenaMeta?

    var items: [ArenaBlockDTO] { data ?? contents ?? [] }
}

struct ArenaMeta: Decodable {
    let hasMorePages: Bool?
    let currentPage: Int?

    enum CodingKeys: String, CodingKey {
        case hasMorePages = "has_more_pages"
        case currentPage  = "current_page"
    }
}

struct ArenaBlockDTO: Decodable {
    let id: Int
    let type: String?
    let `class`: String?   // legacy key
    let title: String?
    let image: ArenaImageDTO?
    let content: ArenaContentDTO?

    var blockType: String { type ?? `class` ?? "" }
}

struct ArenaImageDTO: Decodable {
    let src: String?
    let width: Int?
    let height: Int?
    // legacy nested keys
    let large: ArenaImageSizeDTO?
    let display: ArenaImageSizeDTO?
    let original: ArenaImageSizeDTO?

    var resolvedURL: URL? {
        let raw = src
            ?? large?.url ?? large?.src
            ?? display?.url ?? display?.src
            ?? original?.url ?? original?.src
        return raw.flatMap { URL(string: $0) }
    }
}

struct ArenaImageSizeDTO: Decodable {
    let url: String?
    let src: String?
}

enum ArenaContentDTO: Decodable {
    case text(String)
    case rich(markdown: String?, html: String?)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .text(s)
        } else {
            struct Rich: Decodable { let markdown: String?; let html: String? }
            let r = try container.decode(Rich.self)
            self = .rich(markdown: r.markdown, html: r.html)
        }
    }

    var plainText: String? {
        switch self {
        case .text(let s): return s.isEmpty ? nil : s
        case .rich(let md, let html): return md ?? html
        }
    }
}

// MARK: - Conversion

extension ArenaBlockDTO {
    func toBlock(channelSlug: String) -> ArenaBlock? {
        let type = blockType
        var imageURL: URL? = nil
        var imageW: Int? = nil
        var imageH: Int? = nil

        if let img = image {
            imageURL = img.resolvedURL
            imageW   = img.width
            imageH   = img.height
        }

        let textContent = content?.plainText

        let block = ArenaBlock(
            id: id,
            channelSlug: channelSlug,
            title: title ?? "",
            blockType: type,
            imageURL: imageURL,
            imageWidth: imageW,
            imageHeight: imageH,
            textContent: textContent
        )
        return block.isRenderable ? block : nil
    }
}

// MARK: - Order

enum BlockOrder: String, CaseIterable, Identifiable {
    case random  = "random"
    case newest  = "newest"
    case oldest  = "oldest"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .random:  return "random"
        case .newest:  return "newest first"
        case .oldest:  return "oldest first"
        }
    }
}
