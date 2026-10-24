import CoreGraphics

/// Where Hyper + an arrow key puts the front window.
enum WindowPosition: Equatable {
    case leftHalf
    case rightHalf
    case leftThird
    case rightThird
    case fill
    case center

    /// The position for an arrow key's virtual key code: ← left half, → right half, ↑ fill, ↓ center.
    init?(keyCode: Int64) {
        switch keyCode {
        case 123: self = .leftHalf
        case 124: self = .rightHalf
        case 126: self = .fill
        case 125: self = .center
        default: return nil
        }
    }

    /// Where the same arrow key puts a window it just moved to `previous`: pressed again, a half
    /// becomes a third, and a third goes back to the half.
    func repeated(after previous: WindowPosition?) -> WindowPosition {
        switch (self, previous) {
        case (.leftHalf, .leftHalf): return .leftThird
        case (.rightHalf, .rightHalf): return .rightThird
        default: return self
        }
    }

    /// The window's frame within `visible`, the screen's usable area (without the menu bar and Dock).
    /// Edges are rounded to whole points, so the two halves meet exactly.
    func frame(in visible: CGRect) -> CGRect {
        let half = (visible.width / 2).rounded(.down)
        let third = (visible.width / 3).rounded(.down)
        switch self {
        case .leftHalf:
            return CGRect(x: visible.minX, y: visible.minY, width: half, height: visible.height)
        case .rightHalf:
            return CGRect(x: visible.minX + half, y: visible.minY, width: visible.width - half, height: visible.height)
        case .leftThird:
            return CGRect(x: visible.minX, y: visible.minY, width: third, height: visible.height)
        case .rightThird:
            return CGRect(x: visible.maxX - third, y: visible.minY, width: third, height: visible.height)
        case .fill:
            return visible
        case .center:
            let width = (visible.width * 2 / 3).rounded()
            let height = (visible.height * 3 / 4).rounded()
            return CGRect(
                x: (visible.midX - width / 2).rounded(),
                y: (visible.midY - height / 2).rounded(),
                width: width,
                height: height
            )
        }
    }
}

enum ScreenCoordinates {
    /// Converts between AppKit's screen coordinates (origin at the bottom left of the main screen,
    /// y going up) and Accessibility's (origin at its top left, y going down). The same both ways.
    static func flip(_ rect: CGRect, mainScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: mainScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
