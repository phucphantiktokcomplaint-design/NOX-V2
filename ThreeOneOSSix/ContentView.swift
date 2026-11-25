import SwiftUI
import UIKit

/// NOX V2 navigation shell rebuilt to match the visual language of V1.
/// Existing feature views remain the source of behavior; this file only owns
/// presentation, tab routing, and sheet presentation.
struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: NOXShellTab = .home
    @State private var showSettings = false
    @State private var showLogs = false
    @StateObject private var scanCoordinator = ScanCoordinator()

    var body: some View {
        ZStack {
            NOXShellBackground()
            VStack(spacing: 0) {
                header
                Group {
                    switch selectedTab {
                    case .home:
                        FeatureHubView(onSelectTab: { _ in }, onOpenSettings: openSettings, onOpenLogs: openLogs)
                    case .patch:
                        PatchProjectsView(onOpenSettings: openSettings, onOpenLogs: openLogs)
                    case .admin:
                        adminPage
                    case .info:
                        AcknowledgementsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                shellTabBar
            }
        }
        .tint(NOXShellStyle.cyan)
        .preferredColorScheme(.dark)
        .onChange(of: patchDraftCoordinator.request?.id) { id in
            if id != nil { selectedTab = .patch }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { id in
            if id != nil { selectedTab = .patch }
        }
        .environmentObject(scanCoordinator)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .sheet(isPresented: $scanCoordinator.isPresented) {
            ScanProgressSheet().environmentObject(scanCoordinator).environment(\.appLanguage, language)
        }
        .overlay(alignment: .bottom) {
            if scanCoordinator.isRunning && !scanCoordinator.isPresented {
                ScanRunningBanner().environmentObject(scanCoordinator).environment(\.appLanguage, language)
            }
        }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("NOXAvatar")
                .resizable().scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(NOXShellStyle.cyan.opacity(0.75), lineWidth: 1))
                .shadow(color: NOXShellStyle.cyan.opacity(0.24), radius: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text("NOX V2")
                    .font(.system(size: 18, weight: .black, design: .rounded)).tracking(1.6)
                    .foregroundStyle(LinearGradient(colors: [.white, NOXShellStyle.cyan], startPoint: .leading, endPoint: .trailing))
                Text(selectedTab.subtitle)
                    .font(.system(size: 9, weight: .black, design: .rounded)).tracking(1.35)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("LOCAL UI")
                    .font(.system(size: 9, weight: .black, design: .rounded)).tracking(1)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 13)
        .background(Color.black.opacity(0.22))
        .overlay(alignment: .bottom) { Rectangle().fill(NOXShellStyle.cyan.opacity(0.22)).frame(height: 1) }
    }

    private var shellTabBar: some View {
        HStack(spacing: 0) {
            ForEach(NOXShellTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 9, weight: .black, design: .rounded)).tracking(1)
                    }
                    .foregroundStyle(selectedTab == tab ? NOXShellStyle.cyan : .white.opacity(0.46))
                    .frame(maxWidth: .infinity).frame(height: 62)
                    .background(selectedTab == tab ? NOXShellStyle.cyan.opacity(0.09) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.bottom, 3)
        .background(Color.black.opacity(0.76))
        .overlay(alignment: .top) { Rectangle().fill(NOXShellStyle.cyan.opacity(0.25)).frame(height: 1) }
    }

    private var adminPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 13) {
                adminIdentityCard
                adminActionRow(icon: "gearshape.fill", title: language.text("settings.title"), subtitle: "App preferences and configuration", color: NOXShellStyle.cyan) { openSettings() }
                adminActionRow(icon: "doc.text.magnifyingglass", title: language.text("logs.title"), subtitle: "Application diagnostics and logs", color: .blue) { openLogs() }
                adminActionRow(icon: "checkmark.shield.fill", title: "System status", subtitle: appState.isSupported ? "Support status available" : "Support status unavailable", color: appState.isSupported ? .green : .orange) { openLogs() }
            }
            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 24)
        }
    }

    private var adminIdentityCard: some View {
        VStack(spacing: 9) {
            Image("NOXAvatar").resizable().scaledToFill().frame(width: 70, height: 70)
                .clipShape(Circle()).overlay(Circle().stroke(NOXShellStyle.cyan.opacity(0.8), lineWidth: 1.5))
                .shadow(color: NOXShellStyle.cyan.opacity(0.28), radius: 14)
            Text("NOX V2 CONTROL CENTER").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(.white)
            Text("Settings • Logs • App status").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20)
        .background(NOXShellStyle.card)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(NOXShellStyle.cyan.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func adminActionRow(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(color)
                    .frame(width: 42, height: 42).background(color.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.35))
            }
            .padding(13).background(NOXShellStyle.card)
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(color.opacity(0.22), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func openSettings() { showSettings = true }
    private func openLogs() { showLogs = true }
}

private enum NOXShellTab: String, CaseIterable, Identifiable {
    case home, patch, admin, info
    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
    var subtitle: String {
        switch self { case .home: return "DASHBOARD"; case .patch: return "PATCH CENTER"; case .admin: return "ADMIN PANEL"; case .info: return "INFORMATION" }
    }
    var icon: String { switch self { case .home: return "house"; case .patch: return "square.stack.3d.up"; case .admin: return "slider.horizontal.3"; case .info: return "info.circle" } }
    var selectedIcon: String { switch self { case .home: return "house.fill"; case .patch: return "square.stack.3d.up.fill"; case .admin: return "slider.horizontal.3"; case .info: return "info.circle.fill" } }
}

private enum NOXShellStyle {
    static let cyan = Color(red: 0.04, green: 0.78, blue: 0.94)
    static let card = Color(red: 0.035, green: 0.065, blue: 0.12).opacity(0.88)
}

private struct NOXShellBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.015, green: 0.025, blue: 0.055), .black, Color(red: 0.015, green: 0.04, blue: 0.075)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(NOXShellStyle.cyan.opacity(0.06)).frame(width: 290, height: 290).blur(radius: 80).offset(x: 140, y: -270)
            Circle().fill(Color.blue.opacity(0.05)).frame(width: 260, height: 260).blur(radius: 75).offset(x: -150, y: 320)
        }.ignoresSafeArea()
    }
}
