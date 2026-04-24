import Foundation

// MARK: - Display enums used across Settings + FrameView

enum FitMode: String, CaseIterable, Identifiable {
    case contain  = "contain"
    case cover    = "cover"
    case blurFill = "blurFill"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .contain:  return "contain"
        case .cover:    return "cover"
        case .blurFill: return "blur fill"
        }
    }
    var description: String {
        switch self {
        case .contain:  return "full image, letterboxed"
        case .cover:    return "fill screen, crop edges"
        case .blurFill: return "contain + blurred bg"
        }
    }
}

enum TransitionStyle: String, CaseIterable, Identifiable {
    case instant   = "instant"
    case crossfade = "crossfade"
    case kenBurns  = "kenBurns"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .instant:   return "instant"
        case .crossfade: return "crossfade"
        case .kenBurns:  return "ken burns"
        }
    }
    var description: String {
        switch self {
        case .instant:   return "hard cut"
        case .crossfade: return "smooth fade"
        case .kenBurns:  return "slow pan + zoom"
        }
    }
}

enum LabelVisibility: String, CaseIterable, Identifiable {
    case never  = "never"
    case onHover = "onHover"
    case always = "always"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .never:   return "never"
        case .onHover: return "on hover"
        case .always:  return "always"
        }
    }
}
