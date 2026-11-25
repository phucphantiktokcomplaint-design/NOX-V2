import SwiftUI
import UIKit

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var licenseManager = LicenseManager()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @State private var updateOffer: AppUpdateChecker.Offer?
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    init() {
        setupLogCapture()
        log("app: NOX V2 launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    private func checkForUpdate() {
        Task {
            guard let offer = await AppUpdateChecker.check() else { return }
            await MainActor.run { updateOffer = offer }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    NOXSplashView()
                } else if licenseManager.isActive {
                    ContentView()
                        .environmentObject(licenseManager)
                } else {
                    LicenseActivationView(manager: licenseManager)
                }
            }
            .environmentObject(appState)
            .environmentObject(patchDraftCoordinator)
            .environmentObject(fileOperationCoordinator)
            .environment(\.appLanguage, language)
            .environment(\.locale, language.locale)
            .id(licenseManager.isActive)   // ⚡ Force re-render khi isActive đổi
            .alert(item: $updateOffer) { offer in
                Alert(
                    title: Text(language.text("update.title")),
                    message: Text(language.text("update.message", offer.version)),
                    primaryButton: .default(Text(language.text("update.agree"))) {
                        UIApplication.shared.open(offer.url)
                    },
                    secondaryButton: .cancel(Text(language.text("update.dismiss"))) {
                        AppUpdateChecker.dismiss(version: offer.version)
                    }
                )
            }
            .onAppear {
                licenseManager.beginLaunchSession()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    withAnimation(.easeInOut(duration: 0.35)) { showSplash = false }
                }
                appState.detectSupport()
                checkForUpdate()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                appState.detectSupport()
                Task { await licenseManager.checkSession() }
            }
            .onOpenURL { url in
                patchDraftCoordinator.presentImport(url)
            }
            .preferredColorScheme(.light)
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        // Kernel exploit is intentionally not invoked during launch or by this UI state.
        exploitStatus = .notStarted
        log("app: kernel exploit auto-run disabled")
    }

    func runKernelExploitIfNeeded() {
        log("app: exploit execution is disabled in this build")
    }
}

private struct NOXSplashView: View {
    @State private var glow = false
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.98, blue: 1).ignoresSafeArea()
            Circle().fill(Color.blue.opacity(0.14)).frame(width: 240).blur(radius: 48).offset(y: -70)
            VStack(spacing: 18) {
                Image("NOXAvatar").resizable().scaledToFit().frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 26)).shadow(color: .blue.opacity(0.18), radius: 20)
                Text("NOX").font(.system(size: 34, weight: .black, design: .rounded)).tracking(4).foregroundStyle(Color.black.opacity(0.84))
                Text("PHUC PHAN").font(.system(size: 12, weight: .bold)).tracking(2).foregroundStyle(.secondary)
                ProgressView().tint(.blue).frame(width: 120).padding(.top, 8)
                Text("Initializing…").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            }.opacity(glow ? 1 : 0.84).scaleEffect(glow ? 1 : 0.98)
        }.onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { glow = true } }
    }
}
