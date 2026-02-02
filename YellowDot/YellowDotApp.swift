//
//  YellowDotApp.swift
//  YellowDot
//
//  Created by Alin Panaitiu on 21.12.2021.
//

import Combine
import Defaults
import LaunchAtLogin
import SwiftUI

let cid = CGSMainConnectionID()
let WM = WindowManager()

extension Defaults.Keys {
    static let showMenubarIcon = Key<Bool>("showMenubarIcon", default: true)
    static let indicatorColor = Key<DotColor>("indicatorColor", default: DotColor.dim)
    static let dotColor = Key<DotColor>("dotColor", default: DotColor.adaptive)
    static let launchCount = Key<Int>("launchCount", default: 0)
}

struct WindowInfo {
    var bounds: CGRect // "kCGWindowBounds"
    var memoryUsage: Int // "kCGWindowMemoryUsage"
    var alpha: Int // "kCGWindowAlpha"
    var sharingState: Int // "kCGWindowSharingState"
    var number: Int // "kCGWindowNumber"
    var ownerName: String // "kCGWindowOwnerName"
    var storeType: Int // "kCGWindowStoreType"
    var layer: Int // "kCGWindowLayer"
    var ownerPID: Int // "kCGWindowOwnerPID"
    var isOnscreen: Int // "kCGWindowIsOnscreen"
    var name: String // "kCGWindowName"
    var screen: String? // "display uuid"
    var space: Int? // "space number"

    var isControlCenterColoredIcon: Bool {
        COLORED_MENUBAR_ICON_NAMES.contains(name)
            && CONTROL_CENTER_NAMES.contains(ownerName)
    }

    var isDot: Bool {
        name == "StatusIndicator"
    }

    static func fromInfoDict(_ dict: [String: Any]) -> WindowInfo {
        var rect = CGRect.zero
        if let bounds = dict["kCGWindowBounds"] as? [String: CGFloat],
           let x = bounds["X"], let y = bounds["Y"],
           let width = bounds["Width"], let height = bounds["Height"]
        {
            rect = CGRect(x: x, y: y, width: width, height: height)
        }

        let id = (dict["kCGWindowNumber"] as? Int) ?? 0

        // Safely get screen identifier - may fail with "invalid display identifier" on display changes
        var screen: String? = nil
        var space: Int? = nil

        if id > 0 {
            if let managedDisplay = CGSCopyManagedDisplayForWindow(cid, id)?.takeRetainedValue() as String?,
               !managedDisplay.isEmpty
            {
                screen = managedDisplay
                space = CGSManagedDisplayGetCurrentSpace(cid, screen as CFString?)
            }
        }

        return WindowInfo(
            bounds: rect,
            memoryUsage: (dict["kCGWindowMemoryUsage"] as? Int) ?? 0,
            alpha: (dict["kCGWindowAlpha"] as? Int) ?? 0,
            sharingState: (dict["kCGWindowSharingState"] as? Int) ?? 0,
            number: id,
            ownerName: (dict["kCGWindowOwnerName"] as? String) ?? "",
            storeType: (dict["kCGWindowStoreType"] as? Int) ?? 0,
            layer: (dict["kCGWindowLayer"] as? Int) ?? 0,
            ownerPID: (dict["kCGWindowOwnerPID"] as? Int) ?? 0,
            isOnscreen: (dict["kCGWindowIsOnscreen"] as? Int) ?? 0,
            name: (dict["kCGWindowName"] as? String) ?? "",
            screen: screen,
            space: space
        )
    }
}

let CONTROL_CENTER_NAMES: Set<String> = [
    "Control Center",
    "Control Centre",
    "مركز التحكم",
    "Centre de control",
    "Ovládací centrum",
    "Kontrolcenter",
    "Kontrollzentrum",
    "Κέντρο ελέγχου",
    "Centro de control",
    "Ohjauskeskus",
    "Centre de contrôle",
    "מרכז הבקרה",
    "कंट्रोल सेंटर",
    "Kontrolni centar",
    "Vezérlőközpont",
    "Pusat Kontrol",
    "Centro di Controllo",
    "コントロールセンター",
    "제어 센터",
    "Pusat Kawalan",
    "Bedieningspaneel",
    "Kontrollsenter",
    "Centrum sterowania",
    "Central de Controle",
    "Central de controlo",
    "Centru de control",
    "Пункт управления",
    "Ovládacie centrum",
    "Kontrollcenter",
    "ศูนย์ควบคุม",
    "Denetim Merkezi",
    "Центр керування",
    "Trung tâm điều khiển",
    "控制中心",
]

let COLORED_MENUBAR_ICON_NAMES: Set<String> = [
    "AudioVideoModule",
    "عناصر التحكم في الصوت والفيديو",
    "Controls d’àudio i de vídeo",
    "Ovládání zvuku a videa",
    "Lyd- og videoindstillinger",
    "Audio- und Videosteuerung",
    "Στοιχεία ελέγχου ήχου και βίντεο",
    "Audio and Video Controls",
    "Audio and Video Controls",
    "Audio and Video Controls",
    "Controles de audio y vídeo",
    "Controles de audio y video",
    "Ääni- ja videosäätimet",
    "Commandes audio et vidéo",
    "Contrôles audio et vidéo",
    "פקדי שמע ווידאו",
    "ऑडियो और वीडियो कंट्रोल",
    "Audio i video kontrole",
    "Hang- és videóvezérlők",
    "Kontrol Audio dan Video",
    "Controlli audio e video",
    "オーディオとビデオのコントロール",
    "오디오 및 비디오 제어",
    "Kawalan Audio dan Video",
    "Audio- en videoregelaars",
    "Lyd- og videokontroller",
    "Narzędzia audio i wideo",
    "Controles de Áudio e Vídeo",
    "Controlos de áudio e vídeo",
    "Comenzi audio și video",
    "Элементы управления аудио и видео",
    "Ovládanie audia a videa",
    "Ljud- och videoreglage",
    "ตัวควบคุมเสียงและวิดีโอ",
    "Ses ile Video Denetimleri",
    "Елементи керування звуком і відео",
    "Điều khiển âm thanh và video",
    "音频和视频控制",
    "音訊和影片控制項目",
    "音訊和影片控制項目",
]

func getWindows() -> [WindowInfo] {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
    let infoList = windowsListInfo as! [[String: Any]]

    let dicts = infoList.filter { w in
        guard let name = w["kCGWindowName"] as? String else {
            return false
        }

        return name == "StatusIndicator"
            || name == "Menubar"
            || (
                COLORED_MENUBAR_ICON_NAMES.contains(name)
                    && CONTROL_CENTER_NAMES.contains((w["kCGWindowOwnerName"] as? String) ?? "")
            )
    }

    return dicts.map { WindowInfo.fromInfoDict($0) }
}

/// Detects if Mission Control (Exposé) is currently active.
/// When Mission Control is active, the Dock window's Y coordinate becomes non-zero.
func isMissionControlActive() -> Bool {
    let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
    guard let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
        return false
    }

    for window in windowsListInfo {
        guard let ownerName = window["kCGWindowOwnerName"] as? String,
              ownerName == "Dock",
              let bounds = window["kCGWindowBounds"] as? [String: CGFloat],
              let y = bounds["Y"]
        else {
            continue
        }

        // When Mission Control is active, the Dock window moves (Y > 0)
        if y > 0 {
            return true
        }
    }

    return false
}

@MainActor var windows: [WindowInfo] = []
@MainActor var missionControlActive: Bool = false

/// Tracks ongoing brightness animations by window ID
@MainActor var brightnessAnimations: [CGSWindow: Timer] = [:]

/// Current brightness values for each window (for animation interpolation)
@MainActor var currentBrightness: [CGSWindow: Float] = [:]

/// Target brightness values for each window (to avoid restarting animations)
@MainActor var targetBrightness: [CGSWindow: Float] = [:]

/// Cleans up stale entries from brightness tracking dictionaries
@MainActor func cleanupStaleBrightnessData() {
    let activeWindowIds = Set(windows.map { $0.number })
    currentBrightness = currentBrightness.filter { activeWindowIds.contains($0.key) }
    targetBrightness = targetBrightness.filter { activeWindowIds.contains($0.key) }
    // Don't clean up animations - they have their own cleanup when complete
}

/// Sets window brightness with automatic animation when brightness changes significantly
/// - Parameters:
///   - color: The target dot color
///   - predicate: Filter for which windows to affect
///   - animated: If true, always animate. If false, only animate when brightness change is significant.
@MainActor func setWindowBrightness(color: DotColor, predicate: (WindowInfo) -> Bool, animated: Bool = false) {
    let filteredWindows = windows.filter(predicate)
    guard !filteredWindows.isEmpty else {
        return
    }

    for window in filteredWindows {
        let newTargetBrightness = color.brightness(window: window)
        let currentTarget = targetBrightness[window.number]
        let currentValue = currentBrightness[window.number] ?? 0.0

        // If target hasn't changed and animation is in progress, skip
        if let existingTarget = currentTarget,
           abs(existingTarget - newTargetBrightness) < 0.001,
           brightnessAnimations[window.number] != nil
        {
            continue
        }

        let brightnessChange = abs(newTargetBrightness - currentValue)

        // Animate if explicitly requested OR if brightness changes significantly (> 0.1)
        // This catches fullscreen transitions where menubar background changes
        if animated || brightnessChange > 0.1 {
            #if DEBUG
                print("Animating \(window.name) from \(currentValue) to \(newTargetBrightness)")
            #endif
            animateBrightness(window: window, to: newTargetBrightness, duration: 0.3)
        } else if brightnessChange > 0.001 {
            // Small change - apply immediately without animation
            applyBrightness(window: window, brightness: newTargetBrightness)
            targetBrightness[window.number] = newTargetBrightness
        }
        // If change is negligible (< 0.001), skip entirely
    }
}

/// Immediately applies brightness to a window
@MainActor func applyBrightness(window: WindowInfo, brightness: Float) {
    var ids = [window.number]
    var brightnesses: [Float] = [brightness]
    CGSSetWindowListBrightness(cid, &ids, &brightnesses, Int32(1))
    currentBrightness[window.number] = brightness
}

/// Animates brightness from current value to target over duration
@MainActor func animateBrightness(window: WindowInfo, to newTarget: Float, duration: TimeInterval) {
    // Cancel any existing animation for this window
    brightnessAnimations[window.number]?.invalidate()

    // Record the target
    targetBrightness[window.number] = newTarget

    let startBrightness = currentBrightness[window.number] ?? 0.0
    let steps = 20 // Number of animation steps (increased for smoother animation)
    let stepDuration = duration / Double(steps)
    var currentStep = 0

    let timer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [window] timer in
        mainActor {
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            // Ease-in-out curve for smoother animation
            let easedProgress: Float
            if progress < 0.5 {
                easedProgress = 2.0 * progress * progress
            } else {
                easedProgress = 1.0 - pow(-2.0 * progress + 2.0, 2.0) / 2.0
            }
            let newBrightness = startBrightness + (newTarget - startBrightness) * easedProgress

            applyBrightness(window: window, brightness: newBrightness)

            if currentStep >= steps {
                timer.invalidate()
                brightnessAnimations.removeValue(forKey: window.number)
            }
        }
    }

    brightnessAnimations[window.number] = timer
}

func pub<T: Equatable>(_ key: Defaults.Key<T>) -> Publishers.Filter<Publishers.RemoveDuplicates<Publishers.Drop<AnyPublisher<Defaults.KeyChange<T>, Never>>>> {
    Defaults.publisher(key).dropFirst().removeDuplicates().filter { $0.oldValue != $0.newValue }
}

class WindowManager: ObservableObject {
    @Published var windowToOpen: String? = nil

    func open(_ window: String) {
        windowToOpen = window
    }
}

func mainActor(_ action: @escaping @MainActor () -> Void) {
    Task { await MainActor.run { action() }}
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) static var instance: AppDelegate!

    var application = NSApplication.shared
    var observers: Set<AnyCancellable> = []
    var dotHider: Timer?
    var windowFetcher: Timer?

    /// Prevent App Nap from suspending our timers
    var activityToken: NSObjectProtocol?

    var didBecomeActiveAtLeastOnce = false

    func application(_: NSApplication, open _: [URL]) {
        guard didBecomeActiveAtLeastOnce else {
            return
        }
        guard !Defaults[.showMenubarIcon] else {
            return
        }
        WM.open("settings")
    }

    func applicationDidBecomeActive(_: Notification) {
        guard didBecomeActiveAtLeastOnce else {
            didBecomeActiveAtLeastOnce = true
            return
        }
        guard !Defaults[.showMenubarIcon] else {
            return
        }
        WM.open("settings")
    }

    @MainActor func initDotHider(timeInterval: TimeInterval) {
        setWindowBrightness(color: Defaults[.dotColor], predicate: { $0.isDot })
        setWindowBrightness(color: Defaults[.indicatorColor], predicate: { $0.isControlCenterColoredIcon })

        windowFetcher?.invalidate()
        dotHider?.invalidate()

        windowFetcher = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            mainActor {
                windows = getWindows()
                cleanupStaleBrightnessData()
            }
        }
        dotHider = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            let dotColor = Defaults[.dotColor]
            guard dotColor != .default else { return }
            let indicatorColor = Defaults[.indicatorColor]
            let mcActive = isMissionControlActive()
            mainActor {
                AppDelegate.instance.handleMissionControlTransition(
                    mcActive: mcActive,
                    dotColor: dotColor,
                    indicatorColor: indicatorColor
                )
            }
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        AppDelegate.instance = self
        Defaults[.launchCount] += 1

        // Disable automatic termination - app needs to stay running in background
        ProcessInfo.processInfo.disableAutomaticTermination("YellowDot needs to run continuously to hide the indicator dots")
        ProcessInfo.processInfo.disableSuddenTermination()

        // Disable App Nap - timers need to fire even when app is in background
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "YellowDot needs to continuously monitor and adjust indicator dot colors"
        )

        NSApp.windows.first { $0.title.contains("Settings") }?.close()

        if !CGPreflightScreenCaptureAccess(), Defaults[.indicatorColor] != .default {
            let alert = NSAlert()
            alert.messageText = "Enable menubar icon dimming?"
            alert.informativeText = "To dim the orange/purple/green menubar icons for microphone, screencapture and FaceTime, the app needs to ask for Screen Recording permissions."
            alert.addButton(withTitle: "Yes")
            alert.addButton(withTitle: "No")
            alert.alertStyle = .informational
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                CGRequestScreenCaptureAccess()
            } else {
                Defaults[.indicatorColor] = .default
            }
        }

        initDotHider(timeInterval: 1)

        pub(.dotColor).sink { dotColor in
            setWindowBrightness(color: dotColor.newValue, predicate: { $0.isDot })
        }.store(in: &observers)
        pub(.indicatorColor).sink { indicatorColor in
            CGRequestScreenCaptureAccess()
            setWindowBrightness(color: indicatorColor.newValue, predicate: { $0.isControlCenterColoredIcon })
        }.store(in: &observers)

        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeMainNotification), name: NSWindow.didBecomeMainNotification, object: nil)

        // Listen for space changes to respond faster to Mission Control
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc func activeSpaceDidChange(_ notification: Notification) {
        // Space change notification - trigger immediate check via dotHider logic
        // This provides faster response than waiting for the 1-second timer
        let dotColor = Defaults[.dotColor]
        guard dotColor != .default else { return }
        let indicatorColor = Defaults[.indicatorColor]
        let mcActive = isMissionControlActive()

        mainActor {
            self.handleMissionControlTransition(mcActive: mcActive, dotColor: dotColor, indicatorColor: indicatorColor)
        }
    }

    /// Handles Mission Control state transitions with animations
    /// Centralized logic to avoid duplication between dotHider and activeSpaceDidChange
    @MainActor func handleMissionControlTransition(mcActive: Bool, dotColor: DotColor, indicatorColor: DotColor) {
        let wasMissionControlActive = missionControlActive
        missionControlActive = mcActive

        if mcActive, !wasMissionControlActive {
            // Entering Mission Control - animate to system default color
            setWindowBrightness(color: .default, predicate: { $0.isDot }, animated: true)
            setWindowBrightness(color: .default, predicate: { $0.isControlCenterColoredIcon }, animated: true)
        } else if !mcActive, wasMissionControlActive {
            // Exiting Mission Control - animate back to custom color
            setWindowBrightness(color: dotColor, predicate: { $0.isDot }, animated: true)
            setWindowBrightness(color: indicatorColor, predicate: { $0.isControlCenterColoredIcon }, animated: true)
        } else if !mcActive {
            // Normal operation - apply without animation (handles fullscreen transitions)
            setWindowBrightness(color: dotColor, predicate: { $0.isDot })
            setWindowBrightness(color: indicatorColor, predicate: { $0.isControlCenterColoredIcon })
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    @objc func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window.title == "YellowDot Settings" {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc func windowDidBecomeMainNotification(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window.title == "YellowDot Settings" {
            NSApp.setActivationPolicy(.regular)
        }
    }
}

extension NSAppearance {
    var isDark: Bool {
        name == .vibrantDark || name == .darkAqua
    }

    var isLight: Bool {
        !isDark
    }

    static var dark: NSAppearance? {
        NSAppearance(named: .darkAqua)
    }

    static var light: NSAppearance? {
        NSAppearance(named: .aqua)
    }

    static var vibrantDark: NSAppearance? {
        NSAppearance(named: .vibrantDark)
    }

    static var vibrantLight: NSAppearance? {
        NSAppearance(named: .vibrantLight)
    }
}

func statusBarAppearance(screen: String?) -> NSAppearance? {
    guard let screen else {
        return NSApp.windows.first(where: { $0.className == "NSStatusBarWindow" })?.effectiveAppearance ?? .light
    }

    return NSApp.windows
        .first(where: { $0.className == "NSStatusBarWindow" && $0.screen?.uuid == screen })?
        .effectiveAppearance ?? .light
}

extension NSScreen {
    var id: CGDirectDisplayID? {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return CGDirectDisplayID(id.uint32Value)
    }

    var uuid: String {
        guard let id, let uuid = CGDisplayCreateUUIDFromDisplayID(id) else { return "" }
        let uuidValue = uuid.takeRetainedValue()
        return CFUUIDCreateString(kCFAllocatorDefault, uuidValue) as String
    }
}

enum DotColor: String, Defaults.Serializable {
    case black
    case `default`
    case adaptive
    case white
    case dim

    // Use slightly less extreme value for light to avoid triggering EDR/HDR behavior on XDR displays
    // 1.0 can cause EDR activation on MacBook Pro XDR screens
    private static let darkBrightness: Float = -1.0
    private static let lightBrightness: Float = 0.95

    @MainActor func brightness(window: WindowInfo) -> Float {
        switch self {
        case .black:
            return Self.darkBrightness
        case .default:
            return 0.0
        case .white:
            return Self.lightBrightness
        case .dim:
            return -0.7
        case .adaptive:
            // When menu bar is not visible (fullscreen apps), use dark brightness
            // When menu bar is visible: use dark for light appearance, light for dark appearance
            return (!CGSIsMenuBarVisibleOnSpace(cid, window.space ?? 1) || (statusBarAppearance(screen: window.screen)?.isLight ?? true)) ? Self.darkBrightness : Self.lightBrightness
        }
    }
}

struct ColorPicker: View {
    let title: String
    let blackHelp: String
    let defaultHelp: String
    let adaptiveHelp: String
    let dimHelp: String
    let whiteHelp: String
    let selection: Binding<DotColor>

    var body: some View {
        Picker(title, selection: selection) {
            Text("Black").tag(DotColor.black)
                .help(blackHelp)
            Text("Default").tag(DotColor.default)
                .help(defaultHelp)
            Text("Adaptive").tag(DotColor.adaptive)
                .help(adaptiveHelp)
            Text("Dim").tag(DotColor.dim)
                .help(dimHelp)
            Text("White").tag(DotColor.white)
                .help(whiteHelp)
        }
    }
}

@main
struct YellowDotApp: App {
    init() {}

    @AppStorage("showMenubarIcon") var showMenubarIcon = Defaults[.showMenubarIcon]
    @AppStorage("dotColor") var dotColor = Defaults[.dotColor]
    @AppStorage("indicatorColor") var indicatorColor = Defaults[.indicatorColor]

    @Environment(\.openWindow) var openWindow
    @ObservedObject var wm = WM
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var dotColorPicker: some View {
        ColorPicker(
            title: "Dot color",
            blackHelp: "Makes the dot black.",
            defaultHelp: "Disables any dot color changes",
            adaptiveHelp: "Makes the dot black/white based on the color of the menubar icons.",
            dimHelp: "Makes the dot 70% darker, keeping a bit of its color.",
            whiteHelp: "Makes the dot white.",
            selection: $dotColor
        )
    }

    var indicatorColorPicker: some View {
        ColorPicker(
            title: "Menubar Indicator color",
            blackHelp: "Makes the indicator black.",
            defaultHelp: "Disables any indicator color changes",
            adaptiveHelp: "Makes the indicator black/white based on the color of the menubar icons.",
            dimHelp: "Makes the indicator 70% darker, keeping a bit of its color.",
            whiteHelp: "Makes the indicator white.",
            selection: $indicatorColor
        )
    }

    var body: some Scene {
        MenuBarExtra("YellowDot", systemImage: "circle.fill", isInserted: $showMenubarIcon) {
            Toggle("Show menubar icon", isOn: $showMenubarIcon)
            LaunchAtLogin.Toggle()
            indicatorColorPicker
            dotColorPicker
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(self)
            }
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: showMenubarIcon) { show in
            if !show, appDelegate.didBecomeActiveAtLeastOnce {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .onChange(of: wm.windowToOpen) { window in
            guard let window else { return }
            openWindow(id: window)
            wm.windowToOpen = nil
        }
        Window("YellowDot Settings", id: "settings") {
            VStack(alignment: .trailing) {
                Form {
                    Toggle("Show menubar icon", isOn: $showMenubarIcon)
                    LaunchAtLogin.Toggle()
                    indicatorColorPicker.pickerStyle(.segmented)
                    dotColorPicker.pickerStyle(.segmented)
                }.formStyle(.grouped)
                Button("Quit") {
                    NSApplication.shared.terminate(self)
                }.padding()
            }
            .frame(minWidth: 580, minHeight: 270)
        }
        .defaultSize(width: 580, height: 270)
    }
}
