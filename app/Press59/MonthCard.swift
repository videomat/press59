import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Keeps the `UsageLog` in Press59's preferences. Only counts are stored, never what's typed,
/// and nothing leaves the Mac unless you share the card yourself.
final class UsageStore: ObservableObject {
    private static let usageKey = "usage"

    @Published private(set) var log: UsageLog

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.usageKey),
           let saved = try? JSONDecoder().decode(UsageLog.self, from: data) {
            log = saved
        } else {
            log = UsageLog()
        }
    }

    func record(_ keystroke: Keystroke) {
        let event: UsageEvent
        switch keystroke {
        case let .app(_, appURL, _): event = .app(appURL)
        case .window: event = .windowMove
        case .hyper: event = .hyperKey
        case .settings: return
        }
        log.record(event, at: Date())
        guard let data = try? JSONEncoder().encode(log) else { return }
        UserDefaults.standard.set(data, forKey: Self.usageKey)
    }

    /// This month first, even before any use, then earlier months with use.
    var monthsToShow: [Date] {
        let thisMonth = Calendar.current.startOfMonth(for: Date())
        return [thisMonth] + log.monthsUsed().filter { $0 != thisMonth }
    }

    func reset() {
        log = UsageLog()
        UserDefaults.standard.removeObject(forKey: Self.usageKey)
    }
}

/// Shares a month's card: posting it, the share sheet, copying and (in Debug builds) saving.
@MainActor
struct MonthCardSharing {
    let monthStart: Date
    let usage: MonthUsage
    let keyForApp: (String) -> String?

    var card: MonthCard {
        MonthCard(monthStart: monthStart, usage: usage, keyForApp: keyForApp)
    }

    /// The card at 2×, 1080 pixels square, for posting.
    private func image() -> NSImage? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        return renderer.nsImage
    }

    private func pngData() -> Data? {
        guard let tiff = image()?.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    }

    private var fileName: String { "Press59 \(MonthCard.title(for: monthStart, withYear: true)).png" }

    /// The card as a PNG in the temporary folder, for the share sheet.
    func writeFile() -> URL? {
        guard let data = pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        return (try? data.write(to: url)) == nil ? nil : url
    }

    func copyImage() {
        guard let image = image() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        // PNG as well, which sites take more readily than the TIFF that NSImage writes.
        if let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: .png)
        }
    }

    /// Copies the card and opens a new post with a line about the month. The sites' share links
    /// take text only, so the image goes on the clipboard to paste in.
    func post(on site: PostSite) {
        copyImage()
        NSWorkspace.shared.open(site.composeURL(text: postText))
    }

    /// E.g. "My October with Press59 so far: 1,391 app switches with Caps Lock, most of them to Claude."
    private var postText: String {
        let isThisMonth = Calendar.current.isDate(monthStart, equalTo: Date(), toGranularity: .month)
        var text = "My \(MonthCard.title(for: monthStart)) with Press59\(isThisMonth ? " so far" : ""): "
            + "\(usage.appSwitches.formatted()) app \(usage.appSwitches == 1 ? "switch" : "switches") with Caps Lock"
        if let top = usage.topApps(1).first {
            text += ", most of them to \(AppBinding.name(of: URL(fileURLWithPath: top.path)))"
        }
        return text + ". press59.win"
    }

    func saveImage() {
        guard let data = pngData() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = fileName
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
    }
}

/// Where the card can be posted, through each site's link for starting a post with some text.
enum PostSite: CaseIterable {
    case x
    case bluesky
    case threads

    var name: String {
        switch self {
        case .x: "X"
        case .bluesky: "Bluesky"
        case .threads: "Threads"
        }
    }

    func composeURL(text: String) -> URL {
        var components = switch self {
        case .x: URLComponents(string: "https://x.com/intent/post")!
        case .bluesky: URLComponents(string: "https://bsky.app/intent/compose")!
        case .threads: URLComponents(string: "https://www.threads.net/intent/post")!
        }
        components.queryItems = [URLQueryItem(name: "text", value: text)]
        return components.url!
    }
}

/// The shareable card itself: square, on an orange gradient, the same wherever it's posted.
struct MonthCard: View {
    static let size: CGFloat = 540

    let monthStart: Date
    let usage: MonthUsage
    /// The current shortcut key for an app, by its path, if it still has one.
    let keyForApp: (String) -> String?

    /// Press59's orange, as in the app icon and on press59.win.
    static let orange = Color(red: 1, green: 0.42, blue: 0.17)
    /// Where the gradient ends, bottom right: a burnt orange that keeps white type readable.
    private static let burntOrange = Color(red: 0.72, green: 0.2, blue: 0.06)

    private var isThisMonth: Bool {
        Calendar.current.isDate(monthStart, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your \(Self.title(for: monthStart))")
                    .font(.system(size: 40, weight: .bold))
                Text(isThisMonth ? "with Press59, so far" : "with Press59")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 0) {
                Text(usage.appSwitches.formatted())
                    .font(.system(size: 76, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text(usage.appSwitches == 1 ? "app switch with Caps Lock" : "app switches with Caps Lock")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer(minLength: 20)

            VStack(spacing: 12) {
                ForEach(usage.topApps(3), id: \.path) { app in
                    topApp(path: app.path, count: app.count)
                }
            }

            Spacer(minLength: 20)

            HStack(alignment: .top, spacing: 26) {
                if usage.windowMoves > 0 {
                    stat(usage.windowMoves.formatted(), usage.windowMoves == 1 ? "window move" : "window moves")
                }
                stat("\(usage.longestStreak)", usage.longestStreak == 1 ? "day in a row" : "days in a row")
                if let weekday = usage.busiestWeekday, let hour = usage.busiestHour {
                    stat(Self.weekdayName(weekday), "busiest, around \(Self.hourName(hour))")
                }
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 26, height: 26)
                Text("Caps Lock + a letter switches apps · press59.win")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .foregroundStyle(.white)
        .padding(40)
        .frame(width: Self.size, height: Self.size, alignment: .topLeading)
        .background {
            LinearGradient(colors: [Self.orange, Self.burntOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .environment(\.colorScheme, .dark)
    }

    private func topApp(path: String, count: Int) -> some View {
        let appURL = URL(fileURLWithPath: path)
        return HStack(spacing: 12) {
            Image(nsImage: AppIconCache.icon(for: appURL, pointSize: 36))
                .resizable()
                .frame(width: 36, height: 36)
            Text(AppBinding.name(of: appURL))
                .font(.system(size: 22, weight: .semibold))
                .lineLimit(1)
            if let key = keyForApp(path) {
                KeyChip(key: key.uppercased(), tint: .white)
            }
            Spacer(minLength: 12)
            Text(count.formatted())
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    /// "October", or "October 2025" for a month of another year.
    static func title(for monthStart: Date, withYear: Bool = false) -> String {
        let calendar = Calendar.current
        let sameYear = calendar.component(.year, from: monthStart) == calendar.component(.year, from: Date())
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(withYear || !sameYear ? "LLLL yyyy" : "LLLL")
        return formatter.string(from: monthStart)
    }

    /// "Tuesdays", for weekday 3.
    private static func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] + "s" : ""
    }

    /// "10:00 AM", or "10:00" with a 24-hour clock.
    private static func hourName(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
