import AppKit
import WebKit

struct TodoItem: Codable {
    var id: String
    var section: String
    var title: String
    var done: Bool
}

struct TodoLine: Codable {
    var id: String
    var title: String
    var done: Bool
    var priority: String? = nil

    var category: String {
        if priority == "P0" || priority == "P1" || priority == "会议" { return priority! }
        if priority == "P2" { return "P1" }
        if title.contains("会议") || title.contains("周会") { return "会议" }
        for value in ["P0", "P1"] where title.uppercased().contains(value) { return value }
        return "P1"
    }
}

struct TodoSection: Codable {
    var id: String
    var title: String
    var todos: [TodoLine]
}

struct TodoDocument: Codable {
    var title: String
    var sections: [TodoSection]
}

final class TodoStore {
    private let dataURL: URL
    private let bundledDocumentURL: URL
    private let legacyURL: URL
    var document: TodoDocument

    init() {
        let fileManager = FileManager.default
        let applicationSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let storageDirectory = applicationSupport.appendingPathComponent("FloatingTodo", isDirectory: true)
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        let parent = Bundle.main.bundleURL.deletingLastPathComponent()
        dataURL = storageDirectory.appendingPathComponent("floating-todo-document-data.json")
        bundledDocumentURL = parent.appendingPathComponent("floating-todo-document-data.json")
        legacyURL = parent.appendingPathComponent("floating-todo-webview-data.json")
        if let data = try? Data(contentsOf: dataURL),
           let decoded = try? JSONDecoder().decode(TodoDocument.self, from: data) {
            document = TodoStore.isLegacyDemoDocument(decoded) ? TodoStore.freshDocument() : decoded
        } else if let data = try? Data(contentsOf: bundledDocumentURL),
                  let decoded = try? JSONDecoder().decode(TodoDocument.self, from: data) {
            document = TodoStore.isLegacyDemoDocument(decoded) ? TodoStore.freshDocument() : decoded
        } else if let data = try? Data(contentsOf: legacyURL),
                  let legacyTodos = try? JSONDecoder().decode([TodoItem].self, from: data) {
            let migrated = TodoStore.document(from: legacyTodos)
            document = TodoStore.isLegacyDemoDocument(migrated) ? TodoStore.freshDocument() : migrated
        } else {
            document = TodoStore.freshDocument()
        }
        document = TodoStore.singleSectionDocument(document)
        save()
    }

    static func freshDocument() -> TodoDocument {
        return TodoDocument(
            title: "每日工作",
            sections: [TodoSection(id: "section-\(UUID().uuidString)", title: "每日任务", todos: [])]
        )
    }

    static func singleSectionDocument(_ document: TodoDocument) -> TodoDocument {
        var seenIDs = Set<String>()
        let todos = document.sections.flatMap(\.todos).filter { seenIDs.insert($0.id).inserted }
        let sectionID = document.sections.first?.id ?? "section-\(UUID().uuidString)"
        return TodoDocument(
            title: document.title,
            sections: [TodoSection(id: sectionID, title: "每日任务", todos: todos)]
        )
    }

    static func isLegacyDemoDocument(_ document: TodoDocument) -> Bool {
        _ = document
        return false
    }

    static func document(from todos: [TodoItem]) -> TodoDocument {
        let grouped = Dictionary(grouping: todos, by: { $0.section })
        let sectionTitles = todos.map { $0.section }.reduce(into: [String]()) { result, section in
            if !result.contains(section) { result.append(section) }
        }
        let sections = sectionTitles.map { title in
            TodoSection(
                id: "section-\(abs(title.hashValue))",
                title: title,
                todos: (grouped[title] ?? []).map { TodoLine(id: $0.id, title: $0.title, done: $0.done) }
            )
        }
        return TodoDocument(title: "每日工作", sections: sections)
    }

    func save() {
        document = TodoStore.singleSectionDocument(document)
        if let data = try? JSONEncoder().encode(document) {
            try? data.write(to: dataURL, options: .atomic)
        }
    }
}

final class SortTrafficLightButton: NSButton {
    var isTrafficGroupHovering = false {
        didSet {
            if oldValue != isTrafficGroupHovering {
                needsDisplay = true
            }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isTrafficGroupHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isTrafficGroupHovering = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let diameter: CGFloat = 12
        let circle = NSRect(
            x: bounds.midX - diameter / 2,
            y: bounds.midY - diameter / 2,
            width: diameter,
            height: diameter
        )

        (isTrafficGroupHovering ? NSColor.systemBlue : NSColor(calibratedWhite: 0.84, alpha: 1)).setFill()
        NSBezierPath(ovalIn: circle).fill()

        let borderColor = isTrafficGroupHovering ? NSColor(calibratedWhite: 0, alpha: 0.18) : NSColor(calibratedWhite: 0.67, alpha: 1)
        borderColor.setStroke()
        let border = NSBezierPath(ovalIn: circle.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()

        guard isTrafficGroupHovering else { return }

        NSColor.black.setStroke()
        let icon = NSBezierPath()
        icon.lineWidth = 1.45
        icon.lineCapStyle = .round
        icon.move(to: NSPoint(x: circle.minX + 3.2, y: circle.maxY - 3.6))
        icon.line(to: NSPoint(x: circle.maxX - 3.2, y: circle.maxY - 3.6))
        icon.move(to: NSPoint(x: circle.minX + 3.2, y: circle.midY))
        icon.line(to: NSPoint(x: circle.maxX - 4.4, y: circle.midY))
        icon.move(to: NSPoint(x: circle.minX + 3.2, y: circle.minY + 3.6))
        icon.line(to: NSPoint(x: circle.maxX - 5.6, y: circle.minY + 3.6))
        icon.stroke()
    }
}

final class WindowDragView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, NSWindowDelegate {
    static let activateNotification = Notification.Name("local.codex.floatingtodo.activate")

    let store = TodoStore()
    var panel: NSPanel!
    var containerView: NSView!
    var webView: WKWebView!
    var backgroundView: NSVisualEffectView!
    var backgroundTintView: NSView!
    var expandedDragView: WindowDragView!
    var expanded = false
    var titlebarSortButton: SortTrafficLightButton?
    var trafficLightMonitor: Any?
    var contextMenuMonitor: Any?
    var dragMonitors: [Any] = []
    var dragStartMouse = NSPoint.zero
    var dragStartOrigin = NSPoint.zero
    var dragDidMove = false
    var meetingReminderTimer: Timer?
    var meetingReminderPanel: NSPanel?

    let collapsedSize = NSSize(width: 68, height: 68)
    let expandedSize = NSSize(width: 390, height: 600)
    let minExpandedSize = NSSize(width: 320, height: 420)
    let maxExpandedSize = NSSize(width: 760, height: 920)

    var isLightTheme: Bool {
        UserDefaults.standard.string(forKey: "FloatingTodo.theme") == "light"
    }

    func applyWindowTheme() {
        let appearanceName: NSAppearance.Name = isLightTheme ? .aqua : .darkAqua
        panel.appearance = NSAppearance(named: appearanceName)
        backgroundView.appearance = NSAppearance(named: appearanceName)
        backgroundTintView.layer?.backgroundColor = (isLightTheme
            ? NSColor(calibratedWhite: 1.0, alpha: 0.30)
            : NSColor(calibratedWhite: 0.0, alpha: 0.30)).cgColor
        containerView.layer?.borderColor = (isLightTheme
            ? NSColor.black.withAlphaComponent(0.10)
            : NSColor.white.withAlphaComponent(0.10)).cgColor
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if activateExistingInstance() {
            NSApp.terminate(nil)
            return
        }

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showExistingInstance),
            name: Self.activateNotification,
            object: nil
        )
        NSApp.setActivationPolicy(.accessory)
        createPanel()
        installContextMenuMonitor()
        renderCollapsed()
        panel.orderFrontRegardless()
        startMeetingReminderTimer()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        meetingReminderTimer?.invalidate()
        if let contextMenuMonitor {
            NSEvent.removeMonitor(contextMenuMonitor)
        }
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func activateExistingInstance() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        guard let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { $0.processIdentifier != currentPID && !$0.isTerminated }) else {
            return false
        }

        DistributedNotificationCenter.default().postNotificationName(
            Self.activateNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        existing.activate(options: [.activateIgnoringOtherApps])
        return true
    }

    @objc func showExistingInstance() {
        guard panel != nil else { return }
        if expanded {
            panel.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            renderExpanded()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if panel == nil || webView == nil {
            createPanel()
        }
        renderCollapsed()
        panel.orderFrontRegardless()
        return true
    }

    func createPanel() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "todo")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear

        containerView = NSView(frame: .zero)
        containerView.wantsLayer = true

        backgroundView = NSVisualEffectView(frame: .zero)
        backgroundView.material = .underWindowBackground
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.appearance = NSAppearance(named: .darkAqua)
        backgroundView.wantsLayer = true
        backgroundView.autoresizingMask = [.width, .height]
        containerView.addSubview(backgroundView)

        backgroundTintView = NSView(frame: .zero)
        backgroundTintView.wantsLayer = true
        backgroundTintView.autoresizingMask = [.width, .height]
        containerView.addSubview(backgroundTintView)

        webView.autoresizingMask = [.width, .height]
        containerView.addSubview(webView)

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel = NSPanel(
            contentRect: NSRect(
                x: screenFrame.maxX - collapsedSize.width - 36,
                y: screenFrame.minY + 46,
                width: collapsedSize.width,
                height: collapsedSize.height
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "每日待办"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.acceptsMouseMovedEvents = true
        panel.delegate = self
        panel.contentView = containerView
        backgroundView.frame = containerView.bounds
        backgroundTintView.frame = containerView.bounds
        webView.frame = containerView.bounds

        expandedDragView = WindowDragView(frame: NSRect(
            x: 82,
            y: max(0, containerView.bounds.height - 38),
            width: max(0, containerView.bounds.width - 82),
            height: 38
        ))
        expandedDragView.autoresizingMask = [.width, .minYMargin]
        expandedDragView.isHidden = true
        containerView.addSubview(expandedDragView)
    }

    func savedExpandedSize() -> NSSize {
        let width = UserDefaults.standard.double(forKey: "FloatingTodo.expandedWidth")
        let height = UserDefaults.standard.double(forKey: "FloatingTodo.expandedHeight")
        guard width > 0, height > 0 else { return expandedSize }
        return NSSize(
            width: min(max(width, minExpandedSize.width), maxExpandedSize.width),
            height: min(max(height, minExpandedSize.height), maxExpandedSize.height)
        )
    }

    func place(size: NSSize) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel.setFrame(
            NSRect(
                x: screenFrame.maxX - size.width - 36,
                y: screenFrame.minY + 46,
                width: size.width,
                height: size.height
            ),
            display: true,
            animate: false
        )
    }

    func placeCollapsed() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let savedX = UserDefaults.standard.double(forKey: "FloatingTodo.collapsedX")
        let savedY = UserDefaults.standard.double(forKey: "FloatingTodo.collapsedY")
        let hasSavedPosition = UserDefaults.standard.object(forKey: "FloatingTodo.collapsedX") != nil &&
            UserDefaults.standard.object(forKey: "FloatingTodo.collapsedY") != nil
        let origin = hasSavedPosition
            ? clampedOrigin(NSPoint(x: savedX, y: savedY), size: collapsedSize)
            : NSPoint(x: screenFrame.maxX - collapsedSize.width - 36, y: screenFrame.minY + 46)
        panel.setFrame(NSRect(origin: origin, size: collapsedSize), display: true, animate: false)
    }

    func clampedOrigin(_ origin: NSPoint, size: NSSize) -> NSPoint {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(
            x: min(max(origin.x, screenFrame.minX), screenFrame.maxX - size.width),
            y: min(max(origin.y, screenFrame.minY), screenFrame.maxY - size.height)
        )
    }

    func openCount() -> Int {
        store.document.sections.flatMap { $0.todos }.filter { !$0.done }.count
    }

    func startMeetingReminderTimer() {
        meetingReminderTimer?.invalidate()
        checkMeetingReminders()
        meetingReminderTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.checkMeetingReminders()
        }
        if let meetingReminderTimer {
            RunLoop.main.add(meetingReminderTimer, forMode: .common)
        }
    }

    func checkMeetingReminders() {
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let reminderKey = reminderStorageKey(for: now)
        var reminded = Set(UserDefaults.standard.stringArray(forKey: reminderKey) ?? [])
        var nearest: (todo: TodoLine, seconds: TimeInterval, key: String)?

        for section in store.document.sections where sectionAppliesToToday(section.title, date: now) {
            for todo in section.todos where !todo.done && todo.category == "会议" {
                guard let minutes = timeValue(for: todo.title),
                      let meetingDate = calendar.date(byAdding: .minute, value: minutes, to: startOfToday) else { continue }
                let seconds = meetingDate.timeIntervalSince(now)
                let key = "\(todo.id)-\(minutes)"
                guard seconds > 0, seconds <= 5 * 60, !reminded.contains(key) else { continue }
                if nearest == nil || seconds < nearest!.seconds {
                    nearest = (todo, seconds, key)
                }
            }
        }

        guard let nearest else { return }
        reminded.insert(nearest.key)
        UserDefaults.standard.set(Array(reminded), forKey: reminderKey)
        let remainingMinutes = max(1, Int(ceil(nearest.seconds / 60)))
        showMeetingReminder(title: nearest.todo.title, remainingMinutes: remainingMinutes)
    }

    func sectionAppliesToToday(_ title: String, date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.month, .day], from: date)
        let month = components.month ?? 0
        let day = components.day ?? 0
        let compactToday = String(format: "%02d%02d", month, day)
        let digits = title.filter(\.isNumber)
        if digits.count >= 4 {
            return digits.contains(compactToday)
        }
        if title.contains("月") || title.contains("日") {
            return title.contains("\(month)月\(day)日") || title.contains("\(month)月\(day)")
        }
        return true
    }

    func reminderStorageKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyyMMdd"
        return "FloatingTodo.meetingReminders.\(formatter.string(from: date))"
    }

    func showMeetingReminder(title: String, remainingMinutes: Int) {
        meetingReminderPanel?.orderOut(nil)

        let size = NSSize(width: 250, height: 66)
        let bubble = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        bubble.backgroundColor = .clear
        bubble.isOpaque = false
        bubble.hasShadow = false
        bubble.level = .floating
        bubble.ignoresMouseEvents = false
        bubble.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let content = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        content.material = .sidebar
        content.blendingMode = .behindWindow
        content.state = .active
        content.appearance = NSAppearance(named: .darkAqua)
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.10).cgColor
        content.layer?.cornerRadius = 11
        content.layer?.borderWidth = 1
        content.layer?.borderColor = NSColor(calibratedWhite: 0.40, alpha: 0.75).cgColor

        let dot = NSView(frame: NSRect(x: 15, y: 39, width: 8, height: 8))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor(calibratedRed: 0.275, green: 0.725, blue: 0.914, alpha: 1).cgColor
        dot.layer?.cornerRadius = 4
        content.addSubview(dot)

        let heading = NSTextField(labelWithString: "还有 \(remainingMinutes) 分钟开始")
        heading.frame = NSRect(x: 31, y: 32, width: 178, height: 20)
        heading.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        heading.textColor = NSColor(calibratedRed: 0.31, green: 0.76, blue: 0.95, alpha: 1)
        content.addSubview(heading)

        let meetingTitle = NSTextField(labelWithString: title)
        meetingTitle.frame = NSRect(x: 15, y: 10, width: 220, height: 20)
        meetingTitle.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        meetingTitle.textColor = NSColor(calibratedWhite: 0.94, alpha: 1)
        meetingTitle.lineBreakMode = .byTruncatingTail
        content.addSubview(meetingTitle)

        let closeButton = NSButton(frame: NSRect(x: 218, y: 35, width: 20, height: 20))
        closeButton.title = "×"
        closeButton.isBordered = false
        closeButton.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        closeButton.contentTintColor = NSColor(calibratedWhite: 0.67, alpha: 1)
        closeButton.toolTip = "关闭提醒"
        closeButton.target = self
        closeButton.action = #selector(dismissMeetingReminder)
        content.addSubview(closeButton)

        bubble.contentView = content
        let screenFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = min(max(panel.frame.maxX - size.width, screenFrame.minX), screenFrame.maxX - size.width)
        var y = panel.frame.maxY + 10
        if y + size.height > screenFrame.maxY {
            y = panel.frame.minY - size.height - 10
        }
        bubble.setFrameOrigin(NSPoint(x: x, y: max(screenFrame.minY, y)))
        bubble.orderFrontRegardless()
        meetingReminderPanel = bubble
    }

    @objc func dismissMeetingReminder() {
        meetingReminderPanel?.orderOut(nil)
        meetingReminderPanel = nil
    }

    func renderCollapsed() {
        expanded = false
        endCollapsedDrag()
        uninstallTrafficLightHoverMonitor()
        titlebarSortButton?.removeFromSuperview()
        titlebarSortButton = nil
        panel.title = "每日待办"
        panel.styleMask = [.borderless]
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        containerView.layer?.cornerRadius = collapsedSize.width / 2
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 0.5
        backgroundView.alphaValue = 0.80
        applyWindowTheme()
        expandedDragView.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.minSize = collapsedSize
        panel.maxSize = collapsedSize
        placeCollapsed()
        webView.loadHTMLString(collapsedHTML(), baseURL: nil)
        panel.orderFrontRegardless()
    }

    func renderExpanded() {
        expanded = true
        panel.title = "每日待办"
        panel.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        containerView.layer?.cornerRadius = 16
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 0.5
        backgroundView.alphaValue = 0.80
        applyWindowTheme()
        expandedDragView.isHidden = false
        panel.isMovableByWindowBackground = true
        panel.minSize = minExpandedSize
        panel.maxSize = maxExpandedSize
        place(size: savedExpandedSize())
        webView.loadHTMLString(expandedHTML(), baseURL: nil)
        panel.orderFrontRegardless()
        configureTitlebarSortButton()
        DispatchQueue.main.async { [weak self] in
            self?.styleTrafficLights()
        }
        uninstallTrafficLightHoverMonitor()
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidResize(_ notification: Notification) {
        guard expanded else { return }
        let size = panel.frame.size
        UserDefaults.standard.set(size.width, forKey: "FloatingTodo.expandedWidth")
        UserDefaults.standard.set(size.height, forKey: "FloatingTodo.expandedHeight")
        styleTrafficLights()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        renderCollapsed()
        return false
    }

    func beginCollapsedDrag() {
        guard !expanded, dragMonitors.isEmpty else { return }
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = panel.frame.origin
        dragDidMove = false

        let handler: (NSEvent) -> Void = { [weak self] event in
            self?.handleCollapsedDragEvent(event)
        }
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp], handler: { event in
            handler(event)
            return event
        })
        if let localMonitor {
            dragMonitors.append(localMonitor)
        }
        if let globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged], handler: handler) {
            dragMonitors.append(globalDragMonitor)
        }
        if let globalUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp], handler: handler) {
            dragMonitors.append(globalUpMonitor)
        }
    }

    func handleCollapsedDragEvent(_ event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        let delta = NSPoint(x: mouse.x - dragStartMouse.x, y: mouse.y - dragStartMouse.y)
        let distance = hypot(delta.x, delta.y)

        if event.type == .leftMouseDragged {
            if distance > 3 { dragDidMove = true }
            let origin = clampedOrigin(
                NSPoint(x: dragStartOrigin.x + delta.x, y: dragStartOrigin.y + delta.y),
                size: collapsedSize
            )
            panel.setFrameOrigin(origin)
            UserDefaults.standard.set(origin.x, forKey: "FloatingTodo.collapsedX")
            UserDefaults.standard.set(origin.y, forKey: "FloatingTodo.collapsedY")
        }

        if event.type == .leftMouseUp {
            endCollapsedDrag()
            if !dragDidMove && distance <= 3 {
                renderExpanded()
            }
        }
    }

    func endCollapsedDrag() {
        dragMonitors.forEach { NSEvent.removeMonitor($0) }
        dragMonitors.removeAll()
    }

    @objc func sortFromTitlebarButton() {
        webView.evaluateJavaScript("saveDocument(); send('sortByTime');")
    }

    func configureTitlebarSortButton() {
        titlebarSortButton?.removeFromSuperview()
        titlebarSortButton = nil
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = false
    }

    func styleTrafficLights() {
        guard expanded,
              let closeButton = panel.standardWindowButton(.closeButton),
              let minimizeButton = panel.standardWindowButton(.miniaturizeButton),
              let zoomButton = panel.standardWindowButton(.zoomButton),
              let container = closeButton.superview else { return }

        let leftInset: CGFloat = 14
        let topInset: CGFloat = 14
        let centerSpacing: CGFloat = 20
        for (index, button) in [closeButton, minimizeButton, zoomButton].enumerated() {
            let naturalSize = button.frame.size
            button.setFrameOrigin(NSPoint(
                x: leftInset + CGFloat(index) * centerSpacing,
                y: max(0, container.bounds.height - topInset - naturalSize.height)
            ))
        }
    }

    func installTrafficLightHoverMonitor() {
        guard trafficLightMonitor == nil else { return }
        trafficLightMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.updateTrafficLightHover()
            return event
        }
    }

    func uninstallTrafficLightHoverMonitor() {
        guard let monitor = trafficLightMonitor else { return }
        NSEvent.removeMonitor(monitor)
        trafficLightMonitor = nil
    }

    func updateTrafficLightHover() {
        guard expanded,
              let closeButton = panel.standardWindowButton(.closeButton),
              let zoomButton = panel.standardWindowButton(.zoomButton),
              let sortButton = titlebarSortButton,
              let titlebarView = sortButton.superview else {
            titlebarSortButton?.isTrafficGroupHovering = false
            return
        }

        let mouse = titlebarView.convert(panel.mouseLocationOutsideOfEventStream, from: nil)
        let groupFrame = closeButton.frame
            .union(sortButton.frame)
            .union(zoomButton.frame)
            .insetBy(dx: -7, dy: -8)
        sortButton.isTrafficGroupHovering = groupFrame.contains(mouse)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "todo" else { return }
        if let action = message.body as? String {
            handle(action: action, payload: nil)
            return
        }
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        handle(action: action, payload: body)
    }

    func handle(action: String, payload: [String: Any]?) {
        switch action {
        case "expand":
            renderExpanded()
        case "startCollapsedDrag":
            beginCollapsedDrag()
        case "collapse":
            renderCollapsed()
        case "close":
            NSApp.terminate(nil)
        case "showContextMenu":
            showApplicationContextMenu(payload)
        case "clearDone":
            store.document.sections = store.document.sections.map { section in
                TodoSection(id: section.id, title: section.title, todos: section.todos.filter { !$0.done })
            }.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.todos.isEmpty }
            store.save()
            renderExpanded()
        case "sortByTime":
            sortTodosByTime()
            store.save()
            renderExpanded()
        case "toggle":
            guard let id = payload?["id"] as? String,
                  let sectionIndex = store.document.sections.firstIndex(where: { section in
                      section.todos.contains(where: { $0.id == id })
                  }),
                  let todoIndex = store.document.sections[sectionIndex].todos.firstIndex(where: { $0.id == id }) else { return }
            store.document.sections[sectionIndex].todos[todoIndex].done.toggle()
            store.save()
            renderExpanded()
        case "saveDocument":
            guard let body = payload else { return }
            store.document = decodeDocument(body)
            store.save()
        case "requestPaste":
            pasteFromSystemClipboard()
        case "setTheme":
            guard let theme = payload?["theme"] as? String,
                  theme == "light" || theme == "dark" else { return }
            UserDefaults.standard.set(theme, forKey: "FloatingTodo.theme")
            applyWindowTheme()
        default:
            break
        }
    }

    func showApplicationContextMenu(_ payload: [String: Any]?) {
        let x = (payload?["x"] as? NSNumber)?.doubleValue ?? Double(webView.bounds.midX)
        let y = (payload?["y"] as? NSNumber)?.doubleValue ?? Double(webView.bounds.midY)
        let point = NSPoint(x: x, y: webView.bounds.height - y)
        let menu = applicationContextMenu()
        menu.popUp(positioning: menu.items.first, at: point, in: webView)
    }

    func installContextMenuMonitor() {
        guard contextMenuMonitor == nil else { return }
        contextMenuMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
            guard let self,
                  event.window === panel,
                  event.type == .rightMouseDown || event.modifierFlags.contains(.control) else {
                return event
            }
            NSMenu.popUpContextMenu(applicationContextMenu(), with: event, for: webView)
            return nil
        }
    }

    func applicationContextMenu() -> NSMenu {
        let menu = NSMenu()
        let quitItem = NSMenuItem(
            title: "退出每日待办",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    @objc func quitApplication() {
        NSApp.terminate(nil)
    }

    func sortTodosByTime() {
        store.document.sections = store.document.sections.map { section in
            let sortedTodos = section.todos.enumerated().sorted { left, right in
                if left.element.done != right.element.done { return !left.element.done }
                let ranks = ["P0": 0, "P1": 1, "会议": 2]
                let leftRank = ranks[left.element.category] ?? 1
                let rightRank = ranks[right.element.category] ?? 1
                if leftRank != rightRank { return leftRank < rightRank }
                let leftTime = timeValue(for: left.element.title)
                let rightTime = timeValue(for: right.element.title)
                switch (leftTime, rightTime) {
                case let (.some(leftMinutes), .some(rightMinutes)):
                    return leftMinutes == rightMinutes ? left.offset < right.offset : leftMinutes < rightMinutes
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return left.offset < right.offset
                }
            }.map { $0.element }
            return TodoSection(id: section.id, title: section.title, todos: sortedTodos)
        }
    }

    func timeValue(for text: String) -> Int? {
        if let minutes = firstRegexTime(in: text, pattern: #"(?:(上午|早上|中午|下午|晚上)\s*)?(\d{1,2})[:：](\d{2})"#) {
            return minutes
        }
        return firstRegexTime(in: text, pattern: #"(?:(上午|早上|中午|下午|晚上)\s*)?(\d{1,2})\s*[点时]\s*(半|\d{1,2}\s*分?)?"#)
    }

    func firstRegexTime(in text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let hourRange = Range(match.range(at: 2), in: text) else { return nil }

        let period: String?
        if match.range(at: 1).location != NSNotFound,
           let periodRange = Range(match.range(at: 1), in: text) {
            period = String(text[periodRange])
        } else {
            period = nil
        }

        let rawHour = Int(text[hourRange]) ?? 0
        var minute = 0
        if match.range(at: 3).location != NSNotFound,
           let minuteRange = Range(match.range(at: 3), in: text) {
            let minuteText = String(text[minuteRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if minuteText == "半" {
                minute = 30
            } else {
                minute = Int(minuteText.replacingOccurrences(of: "分", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            }
        }

        let hour = normalizedHour(rawHour, period: period)
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    func normalizedHour(_ hour: Int, period: String?) -> Int {
        guard let period else { return hour }
        if (period == "下午" || period == "晚上") && hour < 12 { return hour + 12 }
        if period == "中午" && hour < 11 { return hour + 12 }
        if (period == "上午" || period == "早上") && hour == 12 { return 0 }
        return hour
    }

    func pasteFromSystemClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: [text]),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.insertPastedTextFromNative(\(json));")
    }

    func decodeDocument(_ body: [String: Any]) -> TodoDocument {
        let title = (body["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawSections = body["sections"] as? [[String: Any]] ?? []
        let sections = rawSections.compactMap { section -> TodoSection? in
            let sectionTitle = (section["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let rawTodos = section["todos"] as? [[String: Any]] ?? []
            let todos = rawTodos.compactMap { todo -> TodoLine? in
                let todoTitle = (todo["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !todoTitle.isEmpty else { return nil }
                return TodoLine(
                    id: (todo["id"] as? String) ?? "memo-\(Int(Date().timeIntervalSince1970 * 1000))",
                    title: todoTitle,
                    done: todo["done"] as? Bool ?? false,
                    priority: todo["priority"] as? String
                )
            }
            guard !sectionTitle.isEmpty || !todos.isEmpty else { return nil }
            return TodoSection(
                id: (section["id"] as? String) ?? "section-\(Int(Date().timeIntervalSince1970 * 1000))",
                title: sectionTitle,
                todos: todos
            )
        }
        return TodoDocument(title: title?.isEmpty == false ? title! : "未命名", sections: sections)
    }

    func jsonDocument() -> String {
        guard let data = try? JSONEncoder().encode(store.document),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"title":"每日工作","sections":[]}"#
        }
        return json
    }

    func collapsedHTML() -> String {
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            * { box-sizing: border-box; }
            html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: transparent; font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif; user-select: none; }
            button {
              position: relative; width: 100%; height: 100%; overflow: hidden;
              border: 1px solid \(isLightTheme ? "#a8adb5" : "#565960"); border-radius: 999px;
              background: transparent;
              color: \(isLightTheme ? "#24272c" : "#f2f3f5");
              box-shadow: none;
              display: grid; place-items: center; cursor: pointer; padding: 0;
            }
            .count {
              position: relative; z-index: 1;
              display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 1px;
              color:\(isLightTheme ? "#24272c" : "#f2f3f5"); font-size:26px; line-height:.88; font-weight:850;
              letter-spacing: 0; transform: translateY(1px);
            }
            .count small {
              color:\(isLightTheme ? "#717780" : "#a9acb2"); font-size:11px; line-height:1; font-weight:650;
            }
          </style>
        </head>
        <body>
          <button
            onmousedown="if (event.button === 0) window.webkit.messageHandlers.todo.postMessage('startCollapsedDrag')"
            oncontextmenu="event.preventDefault(); window.webkit.messageHandlers.todo.postMessage({ action: 'showContextMenu', x: event.clientX, y: event.clientY })"
          >
            <span class="count">\(openCount())<small>待办</small></span>
          </button>
        </body>
        </html>
        """
    }

    func expandedHTML() -> String {
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            * { box-sizing: border-box; }
            html, body {
              margin:0; width:100%; height:100%; overflow:hidden; background:transparent;
              color:#eceef1; font-family:-apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", sans-serif;
            }
            .panel { width:100%; height:100vh; overflow:hidden; background:transparent; }
            main { width:100%; height:100%; min-height:0; overflow:hidden; outline:none; caret-color:transparent; }
            .section { display:flex; flex-direction:column; height:100%; min-height:0; }
            .section-title { display:flex; flex:none; justify-content:space-between; align-items:center; gap:12px; margin:48px 32px 14px; font-size:15px; font-weight:650; color:#f3f5f8; }
            .todo-list { flex:1; min-height:0; overflow-x:hidden; overflow-y:auto; overscroll-behavior:contain; padding:0 32px 32px; }
            .section-title.hidden { display: none; }
            .section-name { min-width:80px; outline:none; border-radius:7px; padding:2px 0; caret-color:#f5f7fa; font-family:-apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif; font-weight:650; font-style:normal; }
            .section-name:focus { background:rgba(255,255,255,.08); box-shadow:none; outline:1px solid rgba(150,184,226,.72); outline-offset:0; }
            .title:focus { background:transparent; box-shadow:none; }
            .section-tools { display:grid; grid-template-columns:repeat(3, 28px); align-items:center; gap:6px; flex:0 0 auto; user-select:none; }
            .tool-button {
              width:28px; height:24px; min-height:24px; display:grid; place-items:center;
              padding:0; border:0; background:transparent; color:#aeb7c5; cursor:pointer; border-radius:7px;
            }
            .tool-button:hover { color:#f6f7f8; background:rgba(255,255,255,.10); }
            .tool-button svg { width:17px; height:17px; stroke-width:2; }
            .todo { position:relative; display:grid; grid-template-columns:20px 34px minmax(0,1fr); align-items:start; column-gap:3px; width:100%; min-height:30px; margin:6px 0; padding:0; border:0; border-radius:8px; box-shadow:none; text-align:left; background:transparent; font-weight:450; }
            .todo:not(.composer):not(:focus-within):hover { background:transparent; }
            .todo:focus-within::before { content:none; }
            .todo > * { position:relative; z-index:1; }
            .todo:has(.priority-wrap:hover), .todo:has(.priority-wrap.open) { grid-template-columns:20px 48px minmax(0,1fr); }
            .priority-wrap { position:relative; display:block; width:34px; height:24px; margin-top:1px; z-index:2; }
            .priority-wrap.open { z-index:1000; }
            .priority { display:flex; align-items:center; justify-content:flex-start; gap:5px; width:34px; height:24px; margin:0; padding:0 0 0 2px; border:0; border-radius:5px; background:transparent; box-shadow:none; font-family:"Avenir Next","PingFang SC",sans-serif; font-size:13px; line-height:18px; font-weight:600; font-style:normal; cursor:pointer; }
            .priority-wrap:hover .priority, .priority-wrap.open .priority { width:48px; padding-left:2px; background:#34363a; outline:1px solid #575b63; }
            .priority-label { display:inline-block; white-space:nowrap; line-height:18px; }
            .priority-wrap[data-value="P0"] .priority-label, .priority-wrap[data-value="P1"] .priority-label { font-weight:700; font-style:oblique 7deg; }
            .priority-wrap[data-value="会议"] .priority-label { font-weight:600; font-style:oblique 2deg; }
            .priority-wrap[data-value="P0"] .priority-label { color:#f15b9a; }
            .priority-wrap[data-value="P1"] .priority-label { color:#f2b705; }
            .priority-wrap[data-value="会议"] .priority-label { color:#46b9e9; }
            .priority-arrow { display:none; width:5px; height:5px; flex:0 0 5px; border-right:1.5px solid #b5bac2; border-bottom:1.5px solid #b5bac2; transform:translateY(-1px) rotate(45deg); }
            .priority-wrap:hover .priority-arrow, .priority-wrap.open .priority-arrow { display:block; }
            .priority-menu { display:none; position:absolute; top:28px; left:0; z-index:1001; width:74px; padding:4px; overflow:hidden; border:1px solid #555960; border-radius:9px; background-color:#303236; opacity:1; isolation:isolate; }
            .priority-wrap.open .priority-menu { display:block; }
            .priority-option { display:block; width:100%; height:30px; padding:0 9px; border:0; border-radius:4px; background:#303236; color:#eceef1; text-align:left; font-family:"Avenir Next","PingFang SC",sans-serif; font-size:13px; line-height:18px; font-weight:600; font-style:normal; cursor:pointer; }
            .priority-option:hover { background:#474a50; }
            .priority-option[data-value="P0"] { color:#f15b9a; }
            .priority-option[data-value="P1"] { color:#f2b705; }
            .priority-option[data-value="会议"] { color:#46b9e9; }
            .priority-option[data-value="P0"], .priority-option[data-value="P1"] { font-weight:700; font-style:oblique 7deg; }
            .priority-option[data-value="会议"] { font-weight:600; font-style:oblique 2deg; }
            .priority:focus-visible { outline:1px solid #8db4e2; outline-offset:1px; }
            .todo.group-start { margin-top:5px; padding-top:0; border-top:0; }
            .check { width:18px; height:18px; margin-top:3px; border:1.5px solid #8f9aa9; border-radius:999px; display:grid; place-items:center; color:#fff; font-size:12px; }
            .check-button { width: 20px; height: 24px; min-height: 24px; padding: 0; border: 0; box-shadow: none; background: transparent; }
            .todo.done .check { border-color:#f2b705; background:#f2b705; }
            .title { min-height:24px; color:#f0f3f7; font-size:14px; line-height:22px; font-weight:450; word-break:break-word; outline:none; border-radius:7px; padding:1px 4px 1px 0; caret-color:#f1f4f8; }
            .title:empty::before { content:attr(data-placeholder); color:#7f8998; }
            .todo.done .title { color:#9aa3b1; text-decoration:none; }
            .composer { margin-top: 10px; }
            .composer .title { color:#c4c7cc; }
            ::-webkit-scrollbar { width:5px; }
            ::-webkit-scrollbar-thumb { background:#63666d; border-radius:999px; }
            ::-webkit-scrollbar-thumb:hover { background:#7a7e86; }
            ::-webkit-scrollbar-track { background:transparent; }
            ::selection { color:#f7f8fa; background:#365b86; }
            body.light { color:#25282e; }
            body.light .section-title, body.light .section-name { color:#25282e; }
            body.light .section-name { caret-color:#25282e; }
            body.light .section-name:focus { background:rgba(0,0,0,.06); outline-color:rgba(64,103,148,.58); }
            body.light .tool-button { color:#747b85; }
            body.light .tool-button:hover { color:#20242a; background:rgba(0,0,0,.07); }
            body.light .todo:not(.composer):not(:focus-within):hover { background:transparent; }
            body.light .priority-wrap:hover .priority, body.light .priority-wrap.open .priority { background:#e8eaed; outline-color:#c3c7cd; }
            body.light .priority-arrow { border-color:#68717c; }
            body.light .priority-menu { border-color:#c7cbd1; background-color:#f3f4f6; }
            body.light .priority-option { background:#f3f4f6; }
            body.light .priority-option:hover { background:#e1e4e8; }
            body.light .check { border-color:#7d8692; color:#fff; }
            body.light .title { color:#292d33; caret-color:#20242a; }
            body.light .title:empty::before { color:#8a929c; }
            body.light .todo.done .title { color:#777f89; }
            body.light .composer .title { color:#666e78; }
            body.light ::-webkit-scrollbar-thumb { background:#a7adb5; }
            body.light ::selection { color:#fff; background:#557da9; }
          </style>
        </head>
        <body class="\(isLightTheme ? "light" : "dark")">
          <div class="panel">
            <main id="editor" contenteditable="false" spellcheck="false"></main>
          </div>
          <script>
            let documentData = \(jsonDocument());
            let currentTheme = '\(isLightTheme ? "light" : "dark")';
            function send(action, extra = {}) { window.webkit.messageHandlers.todo.postMessage({ action, ...extra }); }
            function themeIcon() {
              if (currentTheme === 'dark') {
                return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3.5"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.42 1.42"/><path d="m17.65 17.65 1.42 1.42"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.35 17.65-1.42 1.42"/><path d="m19.07 4.93-1.42 1.42"/></svg>`;
              }
              return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><path d="M20.7 15.1A8.5 8.5 0 0 1 8.9 3.3 8.5 8.5 0 1 0 20.7 15.1Z"/></svg>`;
            }
            function themeButtonHTML() {
              const label = currentTheme === 'dark' ? '切换到浅色' : '切换到深色';
              return `<button id="theme-toggle" class="tool-button" onclick="toggleTheme(event)" title="${label}" aria-label="${label}">${themeIcon()}</button>`;
            }
            function toggleTheme(event) {
              event.preventDefault(); event.stopPropagation();
              currentTheme = currentTheme === 'dark' ? 'light' : 'dark';
              document.body.classList.toggle('light', currentTheme === 'light');
              document.body.classList.toggle('dark', currentTheme === 'dark');
              const button = document.getElementById('theme-toggle');
              const label = currentTheme === 'dark' ? '切换到浅色' : '切换到深色';
              if (button) {
                button.innerHTML = themeIcon();
                button.title = label;
                button.setAttribute('aria-label', label);
              }
              send('setTheme', { theme: currentTheme });
            }
            document.addEventListener('contextmenu', event => {
              event.preventDefault();
              send('showContextMenu', { x:event.clientX, y:event.clientY });
            });
            function cleanText(node) {
              return node.innerText.replace(/\\u00a0/g, ' ').replace(/\\n+/g, ' ').trim();
            }
            function escapeHTML(text) {
              return String(text ?? '').replace(/[&<>"']/g, char => ({
                '&': '&amp;',
                '<': '&lt;',
                '>': '&gt;',
                '"': '&quot;',
                "'": '&#39;'
              }[char]));
            }
            function saveDocument() {
              clearTimeout(saveTimer);
              const sections = [...document.querySelectorAll('.section')].map(section => ({
                id: section.dataset.sectionId,
                title: cleanText(section.querySelector('.section-name') || { innerText: '' }),
                todos: [...section.querySelectorAll('.todo')].map(todo => ({
                  id: todo.dataset.todoId || `memo-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
                  title: cleanText(todo.querySelector('.title')),
                  done: todo.dataset.done === 'true',
                  priority: priorityValue(todo)
                })).filter(todo => todo.title)
              })).filter(section => section.title || section.todos.length);
              send('saveDocument', {
                title: documentData.title || '未命名',
                sections
              });
            }
            let saveTimer = null;
            let undoStack = [];
            let redoStack = [];
            function historySnapshot() {
              const editor = document.getElementById('editor');
              const clone = editor.cloneNode(true);
              clone.querySelectorAll('.priority-wrap.open').forEach(item => item.classList.remove('open'));
              return { html:clone.innerHTML, scrollTop:editor.querySelector('.todo-list')?.scrollTop || 0 };
            }
            function checkpoint() {
              const snapshot = historySnapshot();
              if (undoStack.at(-1)?.html !== snapshot.html) undoStack.push(snapshot);
              if (undoStack.length > 80) undoStack.shift();
              redoStack.length = 0;
            }
            function restoreHistory(snapshot) {
              if (!snapshot) return;
              const editor = document.getElementById('editor');
              editor.innerHTML = snapshot.html;
              const list = editor.querySelector('.todo-list');
              if (list) list.scrollTop = snapshot.scrollTop;
              ensureEmptyComposer();
              updateGroups(); saveDocument();
            }
            function undoChange() {
              const snapshot = undoStack.pop();
              if (!snapshot) return;
              redoStack.push(historySnapshot());
              restoreHistory(snapshot);
            }
            function redoChange() {
              const snapshot = redoStack.pop();
              if (!snapshot) return;
              undoStack.push(historySnapshot());
              restoreHistory(snapshot);
            }
            function category(item) {
              if (['P0','P1','会议'].includes(item.priority)) return item.priority;
              if (item.priority === 'P2') return 'P1';
              if (/会议|周会/.test(item.title || '')) return '会议';
              return (item.title || '').toUpperCase().match(/P[01]/)?.[0] || 'P1';
            }
            function priorityHTML(value = 'P1') {
              value = value === 'P2' ? 'P1' : value;
              return `<span class="priority-wrap" data-value="${value}" contenteditable="false"><button class="priority" type="button" aria-label="优先级或会议" onclick="togglePriorityMenu(this, event)"><span class="priority-label">${value}</span><span class="priority-arrow"></span></button><span class="priority-menu">${['P0','P1','会议'].map(p => `<button class="priority-option" type="button" data-value="${p}" onclick="selectPriority(this, event)">${p}</button>`).join('')}</span></span>`;
            }
            function priorityValue(todo) {
              const value = todo?.querySelector('.priority-wrap')?.dataset.value;
              return value === 'P0' || value === '会议' ? value : 'P1';
            }
            function applyPriority(wrap, value) {
              if (!wrap) return;
              wrap.dataset.value = value;
              wrap.querySelector('.priority-label').textContent = value;
            }
            function togglePriorityMenu(button, event) {
              event.preventDefault(); event.stopPropagation();
              const wrap = button.closest('.priority-wrap');
              const willOpen = !wrap.classList.contains('open');
              document.querySelectorAll('.priority-wrap.open').forEach(item => item.classList.remove('open'));
              wrap.classList.toggle('open', willOpen);
            }
            function selectPriority(option, event) {
              event.preventDefault(); event.stopPropagation();
              checkpoint();
              const wrap = option.closest('.priority-wrap');
              applyPriority(wrap, option.dataset.value);
              wrap.classList.remove('open');
              autoSort();
            }
            function timeValue(text) {
              let match = String(text || '').match(/(?:(上午|早上|中午|下午|晚上)\\s*)?(\\d{1,2})[:：](\\d{2})/);
              if (!match) match = String(text || '').match(/(?:(上午|早上|中午|下午|晚上)\\s*)?(\\d{1,2})\\s*[点时]\\s*(半|\\d{1,2}\\s*分?)?/);
              if (!match) return null;
              let hour = Number(match[2]);
              let minute = match[3] === '半' ? 30 : Number(String(match[3] || '0').replace('分', '').trim());
              if (['下午','晚上'].includes(match[1]) && hour < 12) hour += 12;
              if (['上午','早上'].includes(match[1]) && hour === 12) hour = 0;
              if (hour > 23 || minute > 59) return null;
              return hour * 60 + minute;
            }
            function sortTodosInEditor() {
              const ranks = { P0:0, P1:1, '会议':2 };
              document.querySelectorAll('.section').forEach(section => {
                const list = section.querySelector('.todo-list');
                const composer = section.querySelector('.composer');
                const todos = [...section.querySelectorAll('.todo:not(.composer)')].map((todo, index) => ({ todo, index }));
                todos.sort((left, right) => {
                  const leftDone = left.todo.dataset.done === 'true';
                  const rightDone = right.todo.dataset.done === 'true';
                  if (leftDone !== rightDone) return leftDone ? 1 : -1;
                  const rankDelta = ranks[priorityValue(left.todo)] - ranks[priorityValue(right.todo)];
                  if (rankDelta) return rankDelta;
                  const leftTime = timeValue(cleanText(left.todo.querySelector('.title')));
                  const rightTime = timeValue(cleanText(right.todo.querySelector('.title')));
                  if (leftTime !== null && rightTime !== null && leftTime !== rightTime) return leftTime - rightTime;
                  if (leftTime !== null && rightTime === null) return -1;
                  if (leftTime === null && rightTime !== null) return 1;
                  return left.index - right.index;
                });
                todos.forEach(item => list.insertBefore(item.todo, composer || null));
              });
            }
            function autoSort() {
              sortTodosInEditor();
              updateGroups();
              saveDocument();
            }
            function manualSort() {
              checkpoint();
              autoSort();
            }
            function updateGroups() {
              document.querySelectorAll('.section').forEach(section => {
                let previous = null;
                section.querySelectorAll('.todo:not(.composer)').forEach(todo => {
                  const value = priorityValue(todo);
                  todo.classList.toggle('group-start', previous !== null && previous !== value);
                  previous = value;
                });
              });
            }
            function saveSoon() {
              clearTimeout(saveTimer);
              saveTimer = setTimeout(saveDocument, 220);
            }
            function focusEnd(node) {
              const range = document.createRange();
              range.selectNodeContents(node);
              range.collapse(false);
              const selection = window.getSelection();
              selection.removeAllRanges();
              selection.addRange(range);
              node.focus();
            }
            function findTodoFromSelection() {
              const selection = window.getSelection();
              if (!selection.rangeCount) return null;
              const node = selection.anchorNode?.nodeType === Node.TEXT_NODE ? selection.anchorNode.parentElement : selection.anchorNode;
              return node?.closest?.('.todo');
            }
            function findSectionFromSelection() {
              const selection = window.getSelection();
              if (!selection.rangeCount) return null;
              const node = selection.anchorNode?.nodeType === Node.TEXT_NODE ? selection.anchorNode.parentElement : selection.anchorNode;
              return node?.closest?.('.section');
            }
            function createTodo(afterTodo, section, title = '', recordHistory = true) {
              if (recordHistory) checkpoint();
              const todo = document.createElement('div');
              todo.className = 'todo';
              todo.dataset.todoId = `memo-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
              todo.dataset.done = 'false';
              todo.innerHTML = `<span class="check-button" contenteditable="false" onclick="toggleTodo('${todo.dataset.todoId}')"><span class="check"></span></span>${priorityHTML(afterTodo ? priorityValue(afterTodo) : category({title}))}<span class="title" contenteditable="true" data-placeholder="输入待办..."></span>`;
              if (afterTodo) {
                afterTodo.insertAdjacentElement('afterend', todo);
              } else {
                section.querySelector('.todo-list').appendChild(todo);
              }
              const titleNode = todo.querySelector('.title');
              titleNode.textContent = title;
              focusEnd(titleNode);
              saveSoon();
              return todo;
            }
            function normalizePastedLines(text) {
              return text
                .replace(/\\r\\n?/g, '\\n')
                .split('\\n')
                .map(line => line.trim())
                .filter(Boolean)
                .map(line => {
                  let done = false;
                  let title = line
                    .replace(/^[-*•]\\s+/, '')
                    .replace(/^\\d+[.)、]\\s+/, '');
                  if (/^(✓|✔|✅|☑|\\[x\\]|\\[X\\]|- \\[x\\]|- \\[X\\])\\s*/.test(title)) {
                    done = true;
                    title = title.replace(/^(✓|✔|✅|☑|\\[x\\]|\\[X\\]|- \\[x\\]|- \\[X\\])\\s*/, '');
                  } else {
                    title = title.replace(/^(○|◯|〇|☐|□|\\[ \\]|- \\[ \\])\\s*/, '');
                  }
                  return { title: title.trim(), done };
                })
                .filter(item => item.title);
            }
            function insertPlainTextAtSelection(text) {
              checkpoint();
              const selection = window.getSelection();
              if (!selection.rangeCount) return;
              selection.deleteFromDocument();
              selection.getRangeAt(0).insertNode(document.createTextNode(text));
              selection.collapseToEnd();
              saveSoon();
            }
            function insertPastedText(text) {
              if (!String(text || '').trim()) return;
              checkpoint();
              const lines = normalizePastedLines(text);
              if (lines.length <= 1 && !text.includes('\\n')) {
                insertPlainTextAtSelection(lines[0]?.title || text);
                return;
              }

              const todo = findTodoFromSelection();
              let section = findSectionFromSelection();
              if (!section) section = document.querySelector('.section:last-of-type');
              if (!section) return;

              let anchor = todo?.classList.contains('composer') ? todo.previousElementSibling : todo;
              let itemsToInsert = [...lines];
              if (todo && !todo.classList.contains('composer') && !cleanText(todo.querySelector('.title')) && itemsToInsert.length) {
                const first = itemsToInsert.shift();
                todo.querySelector('.title').textContent = first.title;
                todo.dataset.done = String(first.done);
                todo.classList.toggle('done', first.done);
                todo.querySelector('.check').textContent = first.done ? '✓' : '';
                anchor = todo;
              }
              itemsToInsert.forEach(item => {
                const created = createTodo(anchor?.classList?.contains('todo') ? anchor : null, section, item.title, false);
                created.dataset.done = String(item.done);
                created.classList.toggle('done', item.done);
                created.querySelector('.check').textContent = item.done ? '✓' : '';
                anchor = created;
              });
              document.querySelectorAll('.composer').forEach(item => item.remove());
              ensureEmptyComposer();
              updateGroups();
              saveDocument();
            }
            function pasteTodos(event) {
              const text = event.clipboardData?.getData('text/plain') || '';
              if (!text.trim()) return;
              event.preventDefault();
              insertPastedText(text);
            }
            window.insertPastedTextFromNative = function(payload) {
              const text = Array.isArray(payload) ? payload[0] : payload;
              insertPastedText(text || '');
            };
            function deleteTodo(todo) {
              checkpoint();
              const focusTarget = todo.previousElementSibling?.querySelector?.('.title') || todo.nextElementSibling?.querySelector?.('.title') || todo.closest('.section')?.querySelector('.section-name');
              todo.remove();
              ensureEmptyComposer();
              const nextFocus = document.querySelector('.composer .title') || focusTarget;
              if (nextFocus) focusEnd(nextFocus);
              saveSoon();
            }
            function editorKeydown(event) {
              if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'z') {
                event.preventDefault();
                event.shiftKey ? redoChange() : undoChange();
                return;
              }
              if (event.target.closest('.priority-wrap') || event.isComposing) return;
              const editable = event.target.closest?.('.title, .section-name');
              if (!editable) {
                if (['Enter', 'Backspace', 'Delete', ' '].includes(event.key)) event.preventDefault();
                return;
              }
              const todo = findTodoFromSelection();
              const section = findSectionFromSelection();
              if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'v') {
                event.preventDefault();
                send('requestPaste');
                return;
              }
              if (event.key === 'Enter') {
                event.preventDefault();
                const enteredTime = todo && timeValue(cleanText(todo.querySelector('.title'))) !== null;
                if (todo && !cleanText(todo.querySelector('.title'))) return;
                if (todo?.classList.contains('composer')) {
                  const titleNode = todo.querySelector('.title');
                  const title = cleanText(titleNode);
                  if (!title) return;
                  const realTodo = createTodo(todo.previousElementSibling?.classList?.contains('todo') ? todo.previousElementSibling : null, section, title);
                  applyPriority(realTodo.querySelector('.priority-wrap'), priorityValue(todo));
                  todo.remove();
                  focusEnd(realTodo.querySelector('.title'));
                } else if (todo) {
                  const nextTodo = todo.nextElementSibling;
                  if (nextTodo?.classList.contains('composer')) {
                    focusEnd(nextTodo.querySelector('.title'));
                  } else {
                    createTodo(todo, section);
                  }
                } else if (section) {
                  createTodo(null, section);
                }
                if (enteredTime) setTimeout(autoSort, 0);
              }
              if (event.key === 'Backspace' && todo && !cleanText(todo.querySelector('.title'))) {
                event.preventDefault();
                deleteTodo(todo);
              }
            }
            function toggleTodo(id) {
              const todo = document.querySelector(`[data-todo-id="${id}"]`);
              if (!todo) return;
              checkpoint();
              const done = todo.dataset.done !== 'true';
              todo.dataset.done = String(done);
              todo.classList.toggle('done', done);
              todo.querySelector('.check').textContent = done ? '✓' : '';
              if (done) {
                const section = todo.closest('.section');
                const list = section?.querySelector('.todo-list');
                const composer = section?.querySelector('.composer');
                list?.insertBefore(todo, composer || null);
              }
              updateGroups();
              saveSoon();
            }
            function promoteComposer(todo) {
              if (!todo?.classList.contains('composer')) return todo;
              const title = cleanText(todo.querySelector('.title'));
              if (!title) return todo;
              const id = `memo-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
              todo.classList.remove('composer');
              todo.dataset.todoId = id;
              todo.dataset.done = 'false';
              todo.querySelector('.check-button').setAttribute('onclick', `toggleTodo('${id}')`);
              updateGroups();
              return todo;
            }
            function ensureEmptyComposer() {
              if (document.querySelector('.todo:not(.composer)')) return;
              const section = document.querySelector('.section:last-of-type');
              if (!section || section.querySelector('.composer')) return;
              section.querySelector('.todo-list').insertAdjacentHTML('beforeend', `<div class="todo composer"><span class="check-button" contenteditable="false"><span class="check"></span></span>${priorityHTML()}<span class="title" contenteditable="true" data-placeholder="输入待办..."></span></div>`);
            }
            function clearCompletedInSection(button) {
              const section = button.closest('.section');
              if (!section) return;
              checkpoint();
              section.querySelectorAll('.todo:not(.composer)[data-done="true"]').forEach(todo => todo.remove());
              ensureEmptyComposer();
              saveDocument();
            }
            function render() {
              const editor = document.getElementById('editor');
              editor.addEventListener('keydown', editorKeydown);
              editor.addEventListener('paste', pasteTodos);
              editor.addEventListener('beforeinput', event => {
                if (!event.target.closest?.('.title, .section-name')) event.preventDefault();
              });
              editor.addEventListener('input', event => {
                const composer = event.target.closest?.('.todo.composer');
                if (composer && cleanText(composer.querySelector('.title'))) promoteComposer(composer);
                saveSoon();
              });
              editor.addEventListener('blur', saveDocument, true);
              editor.addEventListener('focusin', event => {
                if (event.target.closest?.('.title, .section-name')) checkpoint();
              });
              editor.addEventListener('focusout', event => {
                const title = event.target.closest?.('.title');
                if (!title || title.closest('.composer') || timeValue(cleanText(title)) === null) return;
                setTimeout(autoSort, 0);
              });
              document.addEventListener('click', () => document.querySelectorAll('.priority-wrap.open').forEach(item => item.classList.remove('open')));
              if (!documentData.sections || documentData.sections.length === 0) {
                documentData.sections = [{ id: `section-${Date.now()}`, title: '每日任务', todos: [] }];
              }
              editor.innerHTML = (documentData.sections || []).map(section => {
                const items = [...(section.todos || [])].sort((left, right) => Number(left.done) - Number(right.done));
                const hasTitle = Boolean((section.title || '').trim());
                return `
                  <section class="section" data-section-id="${section.id}">
                    ${hasTitle ? `<div class="section-title" contenteditable="false"><span class="section-name" contenteditable="true">${escapeHTML(section.title)}</span><span class="section-tools">${themeButtonHTML()}<button class="tool-button" onclick="manualSort()" title="待办后输入时间可排序，如：周会 16:00" aria-label="待办后输入时间可排序，如：周会 16:00"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h8"/><path d="M4 12h6"/><path d="M4 17h4"/><path d="M17 5v14"/><path d="m14 16 3 3 3-3"/></svg></button><button class="tool-button" onclick="clearCompletedInSection(this)" title="清理完成" aria-label="清理完成"><svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><path d="M13 14V6.7a3 3 0 0 1 6 0V14"/><path d="M8.5 14h15"/><path d="M9.5 14l-1.8 11h16.6l-1.8-11"/><path d="M12.8 25v-5.2"/><path d="M16 25v-5.2"/><path d="M19.2 25v-5.2"/></svg></button></span></div>` : ''}
                    <div class="todo-list">
                    ${items.map(item => `
                      <div class="todo ${item.done ? 'done' : ''}" data-todo-id="${item.id}" data-done="${item.done ? 'true' : 'false'}">
                        <span class="check-button" contenteditable="false" onclick="toggleTodo('${item.id}')"><span class="check">${item.done ? '✓' : ''}</span></span>
                        ${priorityHTML(category(item))}
                        <span class="title" contenteditable="true" data-placeholder="输入待办...">${escapeHTML(item.title)}</span>
                      </div>
                    `).join('')}
                    </div>
                  </section>
                `;
              }).join('');
              ensureEmptyComposer();
              updateGroups();
            }
            render();
          </script>
        </body>
        </html>
        """
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
