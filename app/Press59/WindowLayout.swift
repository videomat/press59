import CoreGraphics

/// An arrow key pressed with Hyper.
enum WindowArrow: Equatable {
    case left
    case right
    case up
    case down

    init?(keyCode: Int64) {
        switch keyCode {
        case 123: self = .left
        case 124: self = .right
        case 126: self = .up
        case 125: self = .down
        default: return nil
        }
    }
}

/// Where Hyper + the arrow keys put the front window: a column of the screen and a row within
/// it, or centered.
enum WindowPosition: Equatable {
    enum Column: Equatable {
        case full
        case leftHalf
        case rightHalf
        case leftThird
        case rightThird
    }

    enum Row: Equatable {
        case full
        case top
        case bottom
    }

    case tile(Column, Row)
    case center

    static let fill = WindowPosition.tile(.full, .full)
    static let leftHalf = WindowPosition.tile(.leftHalf, .full)
    static let rightHalf = WindowPosition.tile(.rightHalf, .full)

    /// Where `arrow` puts a window that Press59 just moved to `previous` (nil if it didn't, or the
    /// window has moved since). The arrows combine, so a few presses reach any half, third or quarter:
    /// - ← / →: that half of the screen; again, a third. A top or bottom row is kept.
    /// - ↑ / ↓ on a window at one side: the top or bottom of that column; again, the whole column.
    /// - ↑ otherwise: fill the screen; again, its top half.
    /// - ↓ otherwise: center the window; again, the bottom half of the screen.
    static func next(_ arrow: WindowArrow, after previous: WindowPosition?) -> WindowPosition {
        var column: Column?
        var row = Row.full
        if case let .tile(previousColumn, previousRow) = previous {
            column = previousColumn
            row = previousRow
        }
        let isAtSide = column != nil && column != .full

        switch arrow {
        case .left:
            return .tile(column == .leftHalf ? .leftThird : .leftHalf, row)
        case .right:
            return .tile(column == .rightHalf ? .rightThird : .rightHalf, row)
        case .up:
            if isAtSide, let column { return .tile(column, row == .top ? .full : .top) }
            return previous == .fill ? .tile(.full, .top) : .fill
        case .down:
            if isAtSide, let column { return .tile(column, row == .bottom ? .full : .bottom) }
            return previous == .center ? .tile(.full, .bottom) : .center
        }
    }

    /// The window's frame within `visible`, the screen's usable area (without the menu bar and Dock),
    /// in AppKit coordinates (y going up). Edges are rounded to whole points, so neighbors meet exactly.
    func frame(in visible: CGRect) -> CGRect {
        switch self {
        case .center:
            let width = (visible.width * 2 / 3).rounded()
            let height = (visible.height * 3 / 4).rounded()
            return CGRect(
                x: (visible.midX - width / 2).rounded(),
                y: (visible.midY - height / 2).rounded(),
                width: width,
                height: height
            )
        case let .tile(column, row):
            let half = (visible.width / 2).rounded(.down)
            let third = (visible.width / 3).rounded(.down)
            let x: CGFloat, width: CGFloat
            switch column {
            case .full: (x, width) = (visible.minX, visible.width)
            case .leftHalf: (x, width) = (visible.minX, half)
            case .rightHalf: (x, width) = (visible.minX + half, visible.width - half)
            case .leftThird: (x, width) = (visible.minX, third)
            case .rightThird: (x, width) = (visible.maxX - third, third)
            }
            let lowerHeight = (visible.height / 2).rounded(.down)
            let y: CGFloat, height: CGFloat
            switch row {
            case .full: (y, height) = (visible.minY, visible.height)
            case .bottom: (y, height) = (visible.minY, lowerHeight)
            case .top: (y, height) = (visible.minY + lowerHeight, visible.height - lowerHeight)
            }
            return CGRect(x: x, y: y, width: width, height: height)
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
