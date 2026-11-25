import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - MAIN TAB VIEW (4 tabs: HOME / PATCH / ADMIN / INFO)
// ═══════════════════════════════════════════════════════════════

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseManager: LicenseManager
    @State private var selectedTab: MainTab = .home
    @State private var showIntro = true
    @State private var introProgress: Double = 0

    var body: some View {
        ZStack(alignment: .top) { // ⚡ Đổi thành .top để Banner trượt từ trên xuống
            LinearGradient(colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.90, green: 0.95, blue: 0.99)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Color.white.opacity(0.16).ignoresSafeArea()

            VStack(spacing: 0) {
                appHeader

                Group {
                    switch selectedTab {
                    case .home:
                        HomeTabView()
                    case .patch:
                        PatchTabView()
                    case .admin:
                        AdminTabView()
                    case .info:
                        FelixInfoTabView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }
            
            // ⚡ BANNER THÔNG BÁO TỪ XA
            if let ann = licenseManager.announcement {
                AnnouncementBanner(announcement: ann)
                    .padding(.top, 50) // Đẩy xuống dưới Header
                    .zIndex(100)       // Luôn nổi lên trên cùng
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.light)
        .animation(.easeInOut, value: licenseManager.announcement != nil)
        .overlay {
            if showIntro {
                ZStack {
                    Color(red: 0.96, green: 0.98, blue: 1.0).ignoresSafeArea()
                    VStack(spacing: 14) {
                        Image("NOXAvatar")
                            .resizable().scaledToFill()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.95), lineWidth: 1.2))
                            .shadow(color: .blue.opacity(0.12), radius: 24)
                        Text("NOX").font(.system(size: 42, weight: .black, design: .rounded)).tracking(8).foregroundStyle(Color.primary)
                        Text("PHUC PHAN").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(4).foregroundStyle(Color.blue)
                        ZStack {
                            Circle().stroke(.white.opacity(0.12), lineWidth: 4)
                            Circle().trim(from: 0, to: introProgress)
                                .stroke(LinearGradient(colors: [.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(introProgress * 100))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        }.frame(width: 48, height: 48).padding(.top, 12)
                        Text("INITIALIZING NOX")
                            .font(.system(size: 9, weight: .black, design: .rounded)).tracking(2.2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .transition(.opacity)
                .zIndex(200)
            }
        }
        .task {
            withAnimation(.easeInOut(duration: 1.25)) { introProgress = 1 }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            withAnimation(.easeOut(duration: 0.45)) { showIntro = false }
        }
    }

    private var appHeader: some View {
        HStack(spacing: 12) {
            Image("NOXAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.cyan.opacity(0.75), lineWidth: 1))
                .shadow(color: .cyan.opacity(0.22), radius: 12)

            VStack(alignment: .leading, spacing: 3) {
                Text("NOX")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(ProTheme.titleGradient)

                Text(selectedTab.subtitle)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(ProTheme.primaryGradient)
            }

            Spacer()
            NotificationBellButton()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if selectedTab == tab {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                    .blur(radius: 8)

                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 32, height: 32)
                            }

                            Image(systemName: selectedTab == tab ? tab.iconFilled : tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(selectedTab == tab ? Color.blue : .black.opacity(0.45))
                        }

                        Text(tab.title)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(selectedTab == tab ? Color.blue : .black.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .background(
            Color.white.opacity(0.78)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(height: 1)
                }
        )
    }
}

enum MainTab: String, CaseIterable, Identifiable {
    case home, patch, admin, info

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:  return "HOME"
        case .patch: return "PATCH"
        case .admin: return "ADMIN"
        case .info: return "INFO"
        }
    }

    var subtitle: String {
        switch self {
        case .home:  return "DASHBOARD"
        case .patch: return "PATCH CONTROL"
        case .admin: return "ADMIN PANEL"
        case .info: return "FELIX PHAN • CONTACT"
        }
    }

    var icon: String {
        switch self {
        case .home:  return "house"
        case .patch: return "bolt"
        case .admin: return "person.crop.circle"
        case .info: return "info.circle"
        }
    }

    var iconFilled: String {
        switch self {
        case .home:  return "house.fill"
        case .patch: return "bolt.fill"
        case .admin: return "person.crop.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ANNOUNCEMENT BANNER (GIAO DIỆN THÔNG BÁO)
// ═══════════════════════════════════════════════════════════════

struct AnnouncementBanner: View {
    let announcement: Announcement
    @State private var isDismissed = false
    
    var body: some View {
        if !isDismissed {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(announcement.isUrgent ? .red : Color.blue)
                    
                    Text(announcement.title)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button {
                        withAnimation { isDismissed = true }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                
                Text(announcement.message)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(announcement.date)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.blue.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.88))
                    .shadow(color: .black.opacity(0.6), radius: 10, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(announcement.isUrgent ? Color.red.opacity(0.6) : Color.blue.opacity(0.4), lineWidth: 1.2)
            )
            .padding(.horizontal, 18)
        }
    }
}


struct FelixInfoTabView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Image("NOXAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 82, height: 82)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.cyan.opacity(0.7), lineWidth: 1.5))
                    .shadow(color: Color.cyan.opacity(0.22), radius: 12)
                Text("PHUC PHAN").font(.system(size: 25, weight: .black, design: .rounded)).tracking(3).foregroundStyle(.white)
                Text("NOX V2 • OWNER & SUPPORT").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(.cyan)
                Link(destination: URL(string: "https://zalo.me/0964943392")!) {
                    contactRow("message.fill", "Zalo", "0964943392")
                }
                .buttonStyle(.plain)
                Link(destination: URL(string: "https://t.me/noxvippro")!) {
                    contactRow("paperplane.fill", "Telegram", "@noxvippro")
                }
                .buttonStyle(.plain)
                Link(destination: URL(string: "https://zalo.me/g/cp5gadye2bc4vjwfpg18")!) {
                    Label("Tham gia Group Zalo", systemImage: "person.3.fill")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(16)
                        .background(Color.cyan.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.55), lineWidth: 1))
                }
            }
            .padding(22).frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.cyan.opacity(0.25), lineWidth: 1))
            .padding(18)
        }
    }
    private func contactRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack { Image(systemName: icon).foregroundStyle(.cyan).frame(width: 24); Text(label).foregroundStyle(.white.opacity(0.65)); Spacer(); Text(value).fontWeight(.bold).foregroundStyle(.white) }
            .padding(15).background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14))
    }
}
