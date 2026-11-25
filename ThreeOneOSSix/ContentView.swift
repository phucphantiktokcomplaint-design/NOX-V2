import SwiftUI
import UIKit

private enum NOXV2Tab: Int, CaseIterable {
    case home, patch, admin, info

    var key: String {
        switch self {
        case .home: return "noxv2.tab.home"
        case .patch: return "noxv2.tab.patch"
        case .admin: return "noxv2.tab.admin"
        case .info: return "noxv2.tab.info"
        }
    }
    var icon: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .patch: return "square.stack.3d.up.fill"
        case .admin: return "slider.horizontal.3"
        case .info: return "info.circle.fill"
        }
    }
}

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @State private var selected: NOXV2Tab = .home
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var showAbout = false
    @State private var showLicenseStatus = false
    @State private var showSupport = false

    var body: some View {
        ZStack {
            NOXV2Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Group {
                    switch selected {
                    case .home: home
                    case .patch: patchInventory
                    case .admin: admin
                    case .info: info
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                tabBar
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .sheet(isPresented: $showAbout) { AcknowledgementsView() }
        .sheet(isPresented: $showLicenseStatus) { NOXV2LicenseStatusView() }
        .sheet(isPresented: $showSupport) { NOXV2SupportView() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "hexagon.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(NOXV2Theme.cyan)
                .overlay {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.black)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("NOX V2").font(.system(size: 18, weight: .black, design: .rounded)).tracking(1.5)
                Text(language.text("noxv2.header.subtitle"))
                    .font(.system(size: 10, weight: .semibold)).tracking(1.1)
                    .foregroundStyle(NOXV2Theme.muted)
            }
            Spacer()
            Circle().fill(Color.green).frame(width: 7, height: 7)
            Text(language.text("noxv2.header.local"))
                .font(.system(size: 10, weight: .bold)).foregroundStyle(NOXV2Theme.muted)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(NOXV2Theme.panel.opacity(0.9))
        .overlay(alignment: .bottom) { Rectangle().fill(NOXV2Theme.cyan.opacity(0.25)).frame(height: 1) }
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(language.text("noxv2.home.title"))
                        .font(.system(size: 25, weight: .black, design: .rounded))
                    Text(language.text("noxv2.home.subtitle"))
                        .font(.system(size: 13)).foregroundStyle(NOXV2Theme.muted)
                    HStack(spacing: 8) {
                        statusPill(language.text("noxv2.status.local"), color: NOXV2Theme.cyan)
                        statusPill(language.text("noxv2.status.backend.unconfigured"), color: NOXV2Theme.gold)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [NOXV2Theme.panel, NOXV2Theme.panel2], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(NOXV2Theme.cyan.opacity(0.28), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 10) {
                    statCard(title: language.text("noxv2.stat.version"), value: appVersion, icon: "app")
                    statCard(title: language.text("noxv2.stat.ios"), value: UIDevice.current.systemVersion, icon: "iphone")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(language.text("noxv2.home.quick")).font(.system(size: 14, weight: .bold))
                    quickCard(tab: .patch, title: language.text("noxv2.quick.patch"), subtitle: language.text("noxv2.quick.patch.detail"), icon: "square.stack.3d.up.fill")
                    quickCard(tab: .admin, title: language.text("noxv2.quick.admin"), subtitle: language.text("noxv2.quick.admin.detail"), icon: "slider.horizontal.3")
                    quickCard(tab: .info, title: language.text("noxv2.quick.info"), subtitle: language.text("noxv2.quick.info.detail"), icon: "info.circle.fill")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(language.text("noxv2.notice.title")).font(.system(size: 12, weight: .bold)).foregroundStyle(NOXV2Theme.gold)
                    Text(language.text("noxv2.notice.body")).font(.system(size: 12)).foregroundStyle(NOXV2Theme.muted)
                }
                .padding(14).background(NOXV2Theme.panel).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(16)
        }
    }

    private var patchInventory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                pageTitle(language.text("noxv2.patch.title"), subtitle: language.text("noxv2.patch.subtitle"))
                VStack(alignment: .leading, spacing: 8) {
                    Label(language.text("noxv2.patch.safety.title"), systemImage: "shield.lefthalf.filled")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(NOXV2Theme.gold)
                    Text(language.text("noxv2.patch.safety.body"))
                        .font(.system(size: 12)).foregroundStyle(NOXV2Theme.muted)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(NOXV2Theme.panel).clipShape(RoundedRectangle(cornerRadius: 14))
                PatchInventoryList()
            }.padding(16)
        }
    }

    private var admin: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                pageTitle(language.text("noxv2.admin.title"), subtitle: language.text("noxv2.admin.subtitle"))
                adminButton(icon: "gearshape.fill", title: language.text("noxv2.admin.settings"), detail: language.text("noxv2.admin.settings.detail")) { showSettings = true }
                adminButton(icon: "doc.text.magnifyingglass", title: language.text("noxv2.admin.logs"), detail: language.text("noxv2.admin.logs.detail")) { showLogs = true }
                adminButton(icon: "checkmark.shield.fill", title: language.text("noxv2.admin.license"), detail: language.text("noxv2.admin.license.detail")) { showLicenseStatus = true }
                adminButton(icon: "questionmark.circle.fill", title: language.text("noxv2.admin.support"), detail: language.text("noxv2.admin.support.detail")) { showSupport = true }
                Text(language.text("noxv2.admin.backend.notice"))
                    .font(.system(size: 12)).foregroundStyle(NOXV2Theme.muted)
                    .padding(14).background(NOXV2Theme.panel).clipShape(RoundedRectangle(cornerRadius: 14))
            }.padding(16)
        }
    }

    private var info: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                pageTitle(language.text("noxv2.info.title"), subtitle: language.text("noxv2.info.subtitle"))
                VStack(spacing: 12) {
                    Image(systemName: "hexagon.fill").font(.system(size: 52)).foregroundStyle(NOXV2Theme.cyan)
                    Text("NOX V2").font(.system(size: 23, weight: .black, design: .rounded)).tracking(2)
                    Text(language.text("noxv2.info.description")).font(.system(size: 13)).foregroundStyle(NOXV2Theme.muted).multilineTextAlignment(.center)
                    Text("Base: 3106").font(.system(size: 11, weight: .semibold)).foregroundStyle(NOXV2Theme.gold)
                }.padding(22).frame(maxWidth: .infinity).background(NOXV2Theme.panel).clipShape(RoundedRectangle(cornerRadius: 20))
                adminButton(icon: "doc.text", title: language.text("noxv2.info.licenses"), detail: language.text("noxv2.info.licenses.detail")) { showAbout = true }
            }.padding(16)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(NOXV2Tab.allCases, id: \.self) { tab in
                Button { withAnimation(.easeInOut(duration: 0.18)) { selected = tab } } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon).font(.system(size: 17, weight: .semibold))
                        Text(language.text(tab.key)).font(.system(size: 9, weight: .bold)).tracking(0.5)
                    }
                    .foregroundStyle(selected == tab ? NOXV2Theme.cyan : NOXV2Theme.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(selected == tab ? NOXV2Theme.cyan.opacity(0.08) : .clear)
                }.buttonStyle(.plain)
            }
        }
        .background(NOXV2Theme.panel)
        .overlay(alignment: .top) { Rectangle().fill(NOXV2Theme.cyan.opacity(0.2)).frame(height: 1) }
    }

    private func pageTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 23, weight: .black, design: .rounded))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(NOXV2Theme.muted)
        }
    }
    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text).font(.system(size: 10, weight: .bold)).padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule()).overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 0.7)).foregroundStyle(color)
    }
    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(NOXV2Theme.cyan)
            Text(title).font(.system(size: 10, weight: .bold)).foregroundStyle(NOXV2Theme.muted)
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(NOXV2Theme.panel).clipShape(RoundedRectangle(cornerRadius: 14))
    }
    private func quickCard(tab: NOXV2Tab, title: String, subtitle: String, icon: String) -> some View {
        Button { selected = tab } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(NOXV2Theme.cyan).frame(width: 36, height: 36).background(NOXV2Theme.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .bold))
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(NOXV2Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(NOXV2Theme.muted)
            }.padding(12).background(NOXV2Theme.panel).clipShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }
    private func adminButton(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(NOXV2Theme.cyan).frame(width: 36, height: 36).background(NOXV2Theme.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .bold))
                    Text(detail).font(.system(size: 11)).foregroundStyle(NOXV2Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(NOXV2Theme.muted)
            }.padding(12).background(NOXV2Theme.panel).clipShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

private struct NOXV2LicenseStatusView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    private var endpoint: String {
        (Bundle.main.object(forInfoDictionaryKey: "NOX_LICENSE_SERVER_URL") as? String) ?? ""
    }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Label(language.text("noxv2.license.unconfigured"), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).font(.headline)
                Text(language.text("noxv2.license.description"))
                    .font(.subheadline).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Text(language.text("noxv2.license.endpoint"))
                        .font(.caption.weight(.semibold))
                    Text(endpoint.isEmpty ? language.text("noxv2.license.endpoint.empty") : endpoint)
                        .font(.footnote.monospaced()).textSelection(.enabled)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                Spacer()
            }.padding()
                .navigationTitle(language.text("noxv2.admin.license"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(language.text("common.done")) { dismiss() } } }
        }
    }
}

private struct NOXV2SupportView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "message.fill").font(.system(size: 36)).foregroundStyle(NOXV2Theme.cyan)
                Text(language.text("noxv2.support.title")).font(.headline)
                Text("0964943392").font(.title3.monospaced()).textSelection(.enabled)
                Button {
                    if let url = URL(string: "https://zalo.me/0964943392") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(language.text("noxv2.support.openzalo"), systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity).padding()
                }.buttonStyle(.borderedProminent)
                Button(language.text("noxv2.support.credits")) { dismiss(); }
                    .buttonStyle(.bordered)
                Spacer()
            }.padding()
                .navigationTitle(language.text("noxv2.admin.support"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(language.text("common.done")) { dismiss() } } }
        }
    }
}

private struct PatchInventoryList: View {
    @State private var entries: [String] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entries.isEmpty {
                Label("Patch package inventory unavailable", systemImage: "folder.badge.questionmark")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(NOXV2Theme.muted)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(NOXV2Theme.panel).clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(entries, id: \.self) { name in
                    HStack {
                        Image(systemName: "doc.zipper").foregroundStyle(NOXV2Theme.cyan)
                        Text(name).font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text(languageNeutralStatus).font(.system(size: 9, weight: .bold)).foregroundStyle(NOXV2Theme.gold)
                    }.padding(12).background(NOXV2Theme.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .task { load() }
    }
    private var languageNeutralStatus: String { "READ-ONLY" }
    private func load() {
        guard let resourceURL = Bundle.main.resourceURL else { return }
        let urls = (try? FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil)) ?? []
        entries = urls.filter { $0.pathExtension == "3105" || $0.pathExtension == "3106" }.map(\.lastPathComponent).sorted()
    }
}

private enum NOXV2Theme {
    static let background = Color(hex: 0x030712)
    static let panel = Color(hex: 0x0B1220)
    static let panel2 = Color(hex: 0x101B2C)
    static let cyan = Color(hex: 0x00D9FF)
    static let blue = Color(hex: 0x1677FF)
    static let gold = Color(hex: 0xD8B45A)
    static let muted = Color(hex: 0x91A2B8)
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
