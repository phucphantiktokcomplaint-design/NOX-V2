import SwiftUI
import UIKit
import CryptoKit
import Combine

// MARK: - PATCH PRESET MODEL

private struct PatchPreset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var activeFiles: [String]
    var createdAt = Date()
}

// MARK: - PATCH TAB VIEW

struct PatchTabView: View {

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var patchStore = PatchProjectStore()
    @StateObject private var updateManager = PatchUpdateManager.shared

    // MARK: Core State

    @State private var patchOperationBusy = false
    @State private var status = StatusMessage(
        text: "SYSTEM READY — SELECT A PATCH",
        kind: .info
    )

    @State private var showCleaner = false
    @State private var showDisableAllAlert = false
    @State private var patchStates: [String: Bool] = [:]

    // MARK: Integrated Features

    @State private var presets: [PatchPreset] = []
    @State private var presetName = ""
    @State private var showPresetAlert = false
    @State private var selectedPresetID: UUID?

    @State private var showExplorer = false
    @State private var selectedExplorerFile: String?

    @State private var scanResults: [String] = []
    @State private var isScanning = false

    @State private var notifications: [String] = [
        "PATCH CONTROL initialized"
    ]

    @State private var showNotifications = false
    @State private var showUpdateSheet = false

    @State private var automationEnabled = true
    @State private var showCustomization = false

    @AppStorage("patch_analytics_apply")
    private var applyCount = 0

    @AppStorage("patch_analytics_restore")
    private var restoreCount = 0

    @AppStorage("patch_analytics_errors")
    private var errorCount = 0

    @AppStorage("patch_custom_gold")
    private var goldThemeEnabled = true

    @AppStorage("patch_custom_glow")
    private var glowEnabled = true

    // MARK: Premium Colors

    private enum Premium {
        static let background = Color.clear

        static let card = Color.white.opacity(0.055)

        static let cardLight = Color.white.opacity(0.085)

        static let gold = Color(red: 0.12, green: 0.68, blue: 1.0)

        static let goldLight = Color(red: 0.48, green: 0.86, blue: 1.0)

        static let green = Color(
            red: 0.20, green: 0.85, blue: 0.54
        )

        static let red = Color(
            red: 0.95, green: 0.25, blue: 0.25
        )

        static let orange = Color(
            red: 1.0, green: 0.58, blue: 0.20
        )

        static let secondary = Color.white.opacity(0.48)
        static let border = Color.white.opacity(0.08)
    }

    private var accent: Color { goldThemeEnabled ? .cyan : Color(red: 0.08, green: 0.42, blue: 0.92) }

    // MARK: Status Model

    private enum StatusKind {
        case info, success, warning, error

        var color: Color {
            switch self {
            case .info: return Premium.gold
            case .success: return Premium.green
            case .warning: return Premium.orange
            case .error: return Premium.red
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "lock.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }

    private struct StatusMessage {
        let text: String
        let kind: StatusKind
        var date = Date()
    }

    // MARK: Derived Values

    private var sortedItems: [PatchLibraryItem] {
        patchStore.items.sorted {
            $0.packageURL.lastPathComponent <
            $1.packageURL.lastPathComponent
        }
    }

    private var activeCount: Int {
        patchStates.values.filter { $0 }.count
    }

    private var inactiveCount: Int {
        max(0, sortedItems.count - activeCount)
    }

    private var activeProgress: CGFloat {
        guard !sortedItems.isEmpty else { return 0 }
        return CGFloat(activeCount) / CGFloat(sortedItems.count)
    }

    private var deviceMemory: String {
        let bytes = ProcessInfo.processInfo.physicalMemory
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }

    private var deviceUptime: String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            backgroundDecoration

            ScrollView(showsIndicators: false) {
                VStack(spacing: 17) {

                    topHeader

                    if !updateManager.availableUpdates.isEmpty {
                        updateBanner
                    }

                    commandCenter

                    patchLibrarySection

                    presetSection

                    automationSection

                    explorerSection

                    securitySection

                    analyticsSection

                    notificationSection

                    customizationSection


                    statusBar

                    actionSection

                    footer
                }
                .padding(.horizontal, 17)
                .padding(.top, 12)
                .padding(.bottom, 35)
            }
        }
        .preferredColorScheme(.dark)

        .sheet(isPresented: $showCleaner) {
            CleanerView()
        }

        .sheet(isPresented: $showNotifications) {
            notificationSheet
        }

        .sheet(isPresented: $showExplorer) {
            explorerSheet
        }

        .sheet(isPresented: $showUpdateSheet) {
            PatchUpdateSheet(manager: updateManager)
        }

        .alert("Lưu Patch Preset", isPresented: $showPresetAlert) {
            TextField("Tên cấu hình", text: $presetName)

            Button("Huỷ", role: .cancel) {}

            Button("Lưu") {
                savePreset()
            }
        } message: {
            Text("Lưu trạng thái patch hiện tại thành một cấu hình.")
        }

        .alert("Tắt tất cả patch?", isPresented: $showDisableAllAlert) {
            Button("Huỷ", role: .cancel) {}

            Button("Tắt tất cả", role: .destructive) {
                disableAll()
            }
        } message: {
            Text("Các patch đang bật sẽ được khôi phục về file gốc.")
        }

        .onAppear {
            loadPresets()
            syncPatchStates()

            Task {
                _ = await updateManager.checkForUpdates()
            }
        }

        .onChange(of: scenePhase) { phase in
            if phase == .active, !patchOperationBusy {
                syncPatchStates()
            }
        }

        .onChange(of: patchStore.items.count) { _ in
            if !patchOperationBusy {
                syncPatchStates()
            }
        }
    }

    // MARK: Background

    private var backgroundDecoration: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(accent.opacity(0.055))
                    .frame(width: 260, height: 260)
                    .blur(radius: 90)
                    .position(
                        x: geo.size.width * 0.9,
                        y: 80
                    )

                Circle()
                    .fill(accent.opacity(0.035))
                    .frame(width: 220, height: 220)
                    .blur(radius: 90)
                    .position(
                        x: 0,
                        y: geo.size.height * 0.65
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Header

    private var topHeader: some View {
        HStack(spacing: 12) {
            Image("NOXAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(accent.opacity(0.65), lineWidth: 1)
                )
                .shadow(color: glowEnabled ? accent.opacity(0.22) : .clear, radius: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text("PATCH CONTROL")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white)

                Text("PREMIUM GAMING SYSTEM")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(accent)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(
                            patchOperationBusy
                            ? Premium.orange
                            : Premium.green
                        )
                        .frame(width: 7, height: 7)

                    Text(patchOperationBusy ? "BUSY" : "ONLINE")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1)
                        .foregroundStyle(
                            patchOperationBusy
                            ? Premium.orange
                            : Premium.green
                        )
                }

                Text("V2.0 PREMIUM")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Premium.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: Update Banner

    private var updateBanner: some View {
        Button {
            if let url = URL(string: "https://t.me/+6GPzcWlStNQ2NmI9") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                featureIcon(
                    "arrow.down.circle.fill",
                    color: accent
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("KÊNH THÔNG BÁO CẬP NHẬT")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)

                    Text("Mở nhóm Telegram để nhận phiên bản mới")
                        .font(.system(size: 10))
                        .foregroundStyle(Premium.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(accent)
            }
            .padding(13)
            .premiumCard()
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(accent.opacity(0.4), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Command Center

    private var commandCenter: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(
                "COMMAND CENTER",
                subtitle: "Trung tâm điều khiển hệ thống"
            )

            HStack(spacing: 10) {
                metricCard(
                    "ACTIVE",
                    value: "\(activeCount)",
                    icon: "bolt.fill",
                    color: Premium.green
                )

                metricCard(
                    "INACTIVE",
                    value: "\(inactiveCount)",
                    icon: "power",
                    color: Premium.orange
                )

                metricCard(
                    "TOTAL",
                    value: "\(sortedItems.count)",
                    icon: "square.grid.2x2.fill",
                    color: accent
                )
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("PATCH ACTIVATION")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1)
                        .foregroundStyle(Premium.secondary)

                    Spacer()

                    Text("\(Int(activeProgress * 100))%")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(accent)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.07))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.6), accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geo.size.width * activeProgress
                            )
                    }
                }
                .frame(height: 7)
            }
            .padding(14)
            .premiumCard()

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 9
            ) {
                quickAction(
                    "REFRESH SYSTEM",
                    icon: "arrow.clockwise"
                ) {
                    syncPatchStates()
                    setStatus("Đã đồng bộ trạng thái patch", .success)
                }

                quickAction(
                    "SCAN SECURITY",
                    icon: "shield.lefthalf.filled"
                ) {
                    runSecurityScan()
                }

                quickAction(
                    "SAVE PRESET",
                    icon: "square.and.arrow.down"
                ) {
                    presetName = ""
                    showPresetAlert = true
                }

                quickAction(
                    "NOTIFICATIONS",
                    icon: "bell.badge"
                ) {
                    showNotifications = true
                }
            }
        }
    }

    // MARK: Patch Library

    private var patchLibrarySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeading(
                "PATCH LIBRARY",
                subtitle: "Chọn patch để bật hoặc khôi phục"
            )

            if sortedItems.isEmpty {
                emptyState
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(sortedItems, id: \.id) { item in
                        patchCard(for: item)
                    }
                }
            }
        }
    }

    private func patchCard(for item: PatchLibraryItem) -> some View {
        let filename = item.packageURL.lastPathComponent

        let savedName = UserDefaults.standard.string(
            forKey: "patch_name_\(filename)"
        )

        let displayName = savedName ?? getDefaultName(for: filename)
        let enabled = patchStates[filename] ?? false
        let color = getColorForPatch(filename)

        return Button {
            togglePatch(packageFilename: filename)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    featureIcon(
                        getIconForPatch(filename),
                        color: color
                    )

                    Spacer()

                    Circle()
                        .fill(
                            enabled
                            ? Premium.green
                            : Color.white.opacity(0.2)
                        )
                        .frame(width: 8, height: 8)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(displayName)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("FREE FIRE")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Premium.secondary)
                }

                HStack {
                    Text(enabled ? "ACTIVE" : "DISABLED")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(
                            enabled ? Premium.green : Premium.secondary
                        )

                    Spacer()

                    Image(systemName: enabled ? "power" : "bolt.fill")
                        .foregroundStyle(enabled ? Premium.green : accent)
                }
                .padding(.top, 8)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.white.opacity(0.07))
                        .frame(height: 1)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(
                enabled ? color.opacity(0.12) : Premium.card,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        enabled ? color.opacity(0.5) : Premium.border,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(PremiumPressStyle())
        .disabled(patchOperationBusy)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.fill")
                .font(.system(size: 30))
                .foregroundStyle(accent)

            Text("NO PATCH FOUND")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)

            Text("Chưa có patch trong thư viện.")
                .font(.system(size: 10))
                .foregroundStyle(Premium.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(25)
        .premiumCard()
    }

    // MARK: Patch Presets

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(
                "PATCH PRESETS",
                subtitle: "Lưu và chuyển đổi cấu hình patch"
            )

            Button {
                presetName = ""
                showPresetAlert = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(accent)

                    Text("CREATE NEW PRESET")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "plus")
                        .foregroundStyle(accent)
                }
                .padding(13)
                .premiumCard()
            }
            .buttonStyle(.plain)

            if presets.isEmpty {
                Text("Chưa có cấu hình nào được lưu.")
                    .font(.system(size: 10))
                    .foregroundStyle(Premium.secondary)
                    .padding(12)
            } else {
                ForEach(presets) { preset in
                    HStack(spacing: 10) {
                        featureIcon(
                            "square.stack.3d.up.fill",
                            color: accent
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)

                            Text("\(preset.activeFiles.count) patch trong cấu hình")
                                .font(.system(size: 9))
                                .foregroundStyle(Premium.secondary)
                        }

                        Spacer()

                        Button {
                            applyPreset(preset)
                        } label: {
                            Text("APPLY")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Premium.background)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(accent, in: Capsule())
                        }
                        .disabled(patchOperationBusy)

                        Button {
                            deletePreset(preset)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Premium.red)
                        }
                    }
                    .padding(12)
                    .premiumCard()
                }
            }
        }
    }

    // MARK: Smart Automation

    private var automationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(
                "SMART AUTOMATION",
                subtitle: "Tự động kiểm tra và nhắc cập nhật"
            )

            HStack {
                featureIcon("gearshape.2.fill", color: accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("AUTO UPDATE CHECK")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)

                    Text("Kiểm tra phiên bản khi mở ứng dụng")
                        .font(.system(size: 9))
                        .foregroundStyle(Premium.secondary)
                }

                Spacer()

                Toggle("", isOn: $automationEnabled)
                    .labelsHidden()
                    .tint(accent)
            }
            .padding(13)
            .premiumCard()

            Button {
                guard !patchOperationBusy else { return }

                Task {
                    let updates = await updateManager.checkForUpdates()

                    await MainActor.run {
                        if !updates.isEmpty {
                            showUpdateSheet = true
                            setStatus("Có bản cập nhật mới", .success)
                        } else {
                            setStatus("Đã kiểm tra — chưa có bản cập nhật", .info)
                        }
                    }
                }
            } label: {
                featureRow(
                    "CHECK FOR UPDATES",
                    subtitle: "Kiểm tra bản cập nhật ngay",
                    icon: "arrow.clockwise",
                    color: accent
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Patch Explorer

    private var explorerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(
                "PATCH EXPLORER",
                subtitle: "Thông tin chi tiết các file"
            )

            Button {
                showExplorer = true
            } label: {
                featureRow(
                    "OPEN FILE EXPLORER",
                    subtitle: "\(sortedItems.count) file trong thư viện",
                    icon: "folder.fill",
                    color: accent
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var explorerSheet: some View {
        NavigationStack {
            List {
                ForEach(sortedItems, id: \.id) { item in
                    let filename = item.packageURL.lastPathComponent
                    let attributes = try? FileManager.default.attributesOfItem(
                        atPath: item.packageURL.path
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(filename)
                            .font(.system(size: 12, weight: .bold))

                        Text(
                            "Dung lượng: \(formattedSize(attributes?[.size] as? NSNumber))"
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                        Text(
                            "Trạng thái: \((patchStates[filename] ?? false) ? "ACTIVE" : "DISABLED")"
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(
                            patchStates[filename] == true
                            ? .green : .secondary
                        )
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("Patch Explorer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") {
                        showExplorer = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Security Scanner

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(
                "SECURITY SCANNER",
                subtitle: "Kiểm tra file trong thư viện"
            )

            Button {
                runSecurityScan()
            } label: {
                HStack {
                    if isScanning {
                        ProgressView()
                            .tint(accent)
                    } else {
                        featureIcon(
                            "shield.lefthalf.filled",
                            color: accent
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isScanning ? "SCANNING..." : "START SECURITY SCAN")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)

                        Text("Kiểm tra file, dung lượng và SHA-256")
                            .font(.system(size: 9))
                            .foregroundStyle(Premium.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(accent)
                }
                .padding(13)
                .premiumCard()
            }
            .buttonStyle(.plain)
            .disabled(isScanning || patchOperationBusy)

            ForEach(scanResults, id: \.self) { result in
                Text(result)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Premium.secondary)
                    .padding(.horizontal, 8)
            }
        }
    }

    // MARK: Analytics

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(
                "ANALYTICS CENTER",
                subtitle: "Thống kê hoạt động của ứng dụng"
            )

            HStack(spacing: 10) {
                metricCard(
                    "APPLY",
                    value: "\(applyCount)",
                    icon: "bolt.fill",
                    color: Premium.green
                )

                metricCard(
                    "RESTORE",
                    value: "\(restoreCount)",
                    icon: "arrow.uturn.backward",
                    color: accent
                )

                metricCard(
                    "ERRORS",
                    value: "\(errorCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: Premium.red
                )
            }

            Button {
                applyCount = 0
                restoreCount = 0
                errorCount = 0
                setStatus("Đã đặt lại thống kê", .info)
            } label: {
                featureRow(
                    "RESET ANALYTICS",
                    subtitle: "Xoá số liệu thống kê cục bộ",
                    icon: "arrow.counterclockwise",
                    color: Premium.orange
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Notification Center

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(
                "NOTIFICATION CENTER",
                subtitle: "Hoạt động gần đây"
            )

            Button {
                showNotifications = true
            } label: {
                featureRow(
                    "VIEW NOTIFICATIONS",
                    subtitle: "\(notifications.count) thông báo",
                    icon: "bell.badge.fill",
                    color: accent
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var notificationSheet: some View {
        NavigationStack {
            List {
                ForEach(
                    Array(notifications.enumerated()),
                    id: \.offset
                ) { _, message in
                    Label(message, systemImage: "bell")
                        .font(.system(size: 12))
                }
            }
            .navigationTitle("Notification Center")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") {
                        showNotifications = false
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Xoá") {
                        notifications.removeAll()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Customization Studio

    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(
                "CUSTOMIZATION STUDIO",
                subtitle: "Tuỳ chỉnh giao diện"
            )

            VStack(spacing: 18) {
                HStack {
                    Text("NEON BLUE THEME")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Toggle("", isOn: $goldThemeEnabled)
                        .labelsHidden()
                        .tint(accent)
                }

                HStack {
                    Text("GLOW EFFECT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Toggle("", isOn: $glowEnabled)
                        .labelsHidden()
                        .tint(accent)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .premiumCard()
        }
    }

    // MARK: Status Bar

    private var statusBar: some View {
        HStack(spacing: 10) {
            if patchOperationBusy {
                ProgressView()
                    .tint(accent)
            } else {
                Image(systemName: status.kind.icon)
                    .foregroundStyle(status.kind.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SYSTEM LOG")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Premium.secondary)

                Text(
                    patchOperationBusy
                    ? "PROCESSING..."
                    : status.text
                )
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            }

            Spacer()

            Text(status.date, format: .dateTime.hour().minute().second())
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(accent)
        }
        .padding(13)
        .premiumCard()
    }

    // MARK: Main Actions

    private var actionSection: some View {
        VStack(spacing: 10) {
            Button {
                launchGame()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("LAUNCH FREE FIRE")
                            .font(.system(size: 12, weight: .black))

                        Text("Khởi chạy trò chơi")
                            .font(.system(size: 9))
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                }
                .foregroundStyle(Color.white)
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(accent.opacity(0.9), lineWidth: 1.25)
                        }
                        .shadow(color: accent.opacity(0.18), radius: 7, x: 0, y: 0)
                }
            }
            .buttonStyle(PremiumPressStyle())

            Button {
                showCleaner = true
            } label: {
                featureRow(
                    "CLEAN CACHE & TEMP",
                    subtitle: "Dọn dẹp dữ liệu tạm",
                    icon: "trash.slash.fill",
                    color: Premium.orange
                )
            }
            .buttonStyle(.plain)

            if activeCount > 0 {
                Button {
                    showDisableAllAlert = true
                } label: {
                    featureRow(
                        "DISABLE ALL PATCH",
                        subtitle: "Khôi phục toàn bộ patch đang bật",
                        icon: "power",
                        color: Premium.red
                    )
                }
                .buttonStyle(.plain)
                .disabled(patchOperationBusy)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(accent.opacity(0.4))
                .frame(height: 1)

            Text("NOX V2 • FELIX PHAN")
                .font(.system(size: 8, weight: .black))
                .tracking(1.2)
                .foregroundStyle(accent)

            Text("MANAGE YOUR PATCHES WITH CONTROL")
                .font(.system(size: 7))
                .tracking(1)
                .foregroundStyle(Premium.secondary)
        }
        .padding(.top, 6)
    }

    // MARK: Reusable UI

    private func sectionHeading(
        _ title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .black))
                .tracking(1.3)
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(Premium.secondary)
        }
    }

    private func featureIcon(
        _ icon: String,
        color: Color
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(color.opacity(0.13))
                .frame(width: 38, height: 38)

            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private func metricCard(
        _ title: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text(title)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .premiumCard()
    }

    private func monitorItem(
        _ title: String,
        value: String,
        icon: String
    ) -> some View {
        HStack(spacing: 9) {
            featureIcon(icon, color: accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Premium.secondary)

                Text(value)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .premiumCard()
    }

    private func featureRow(
        _ title: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 11) {
            featureIcon(icon, color: color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(Premium.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(12)
        .premiumCard()
    }

    private func quickAction(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .premiumCard()
        }
        .buttonStyle(.plain)
        .disabled(patchOperationBusy)
    }

    // MARK: Preset Storage

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(
            forKey: "patch_saved_presets"
        ) else {
            return
        }

        presets = (try? JSONDecoder().decode(
            [PatchPreset].self,
            from: data
        )) ?? []
    }

    private func persistPresets() {
        guard let data = try? JSONEncoder().encode(presets) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: "patch_saved_presets"
        )
    }

    private func savePreset() {
        let name = presetName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !name.isEmpty else {
            setStatus("Vui lòng nhập tên preset", .warning)
            return
        }

        let activeFiles = patchStates
            .filter { $0.value }
            .map { $0.key }

        let preset = PatchPreset(
            name: name,
            activeFiles: activeFiles
        )

        presets.insert(preset, at: 0)
        persistPresets()

        addNotification("Đã lưu preset: \(name)")
        setStatus("Preset saved successfully", .success)
    }

    private func deletePreset(_ preset: PatchPreset) {
        presets.removeAll { $0.id == preset.id }
        persistPresets()

        addNotification("Đã xoá preset: \(preset.name)")
        setStatus("Đã xoá preset", .info)
    }

    // MARK: Apply Preset

    private func applyPreset(_ preset: PatchPreset) {
        guard !patchOperationBusy else { return }

        let items = patchStore.items
        let desiredFiles = Set(preset.activeFiles)

        patchOperationBusy = true

        DispatchQueue.global(qos: .userInitiated).async {
            var applied = 0
            var restored = 0
            var failed = 0
            var states: [String: Bool] = [:]
            var lockedItems: [PatchLibraryItem] = []

            for item in items {
                let filename = item.packageURL.lastPathComponent
                let shouldBeActive = desiredFiles.contains(filename)

                let receipt = DevicePatchService.latestReceipt(
                    projectID: item.id
                )

                if shouldBeActive {
                    if receipt != nil {
                        states[filename] = true
                        continue
                    }

                    guard let project = item.project else {
                        lockedItems.append(item)
                        states[filename] = false
                        continue
                    }

                    do {
                        _ = try DevicePatchService.apply(project: project)
                        applied += 1
                    } catch {
                        failed += 1
                    }

                } else {
                    guard let receipt else {
                        states[filename] = false
                        continue
                    }

                    do {
                        try DevicePatchService.restore(receipt: receipt)
                        restored += 1
                    } catch {
                        failed += 1
                    }
                }

                states[filename] =
                    DevicePatchService.latestReceipt(projectID: item.id) != nil
            }

            for item in items {
                states[item.packageURL.lastPathComponent] =
                    DevicePatchService.latestReceipt(projectID: item.id) != nil
            }

            DispatchQueue.main.async {
                patchStates = states

                for item in lockedItems {
                    patchStore.requestUnlock(for: item)
                }

                applyCount += applied
                restoreCount += restored
                errorCount += failed

                setStatus(
                    "Preset: +\(applied) Apply • \(restored) Restore • \(failed) lỗi",
                    failed > 0 ? .warning : .success
                )

                addNotification("Đã áp dụng preset: \(preset.name)")
                patchOperationBusy = false
            }
        }
    }

    // MARK: Security Scan

    private func runSecurityScan() {
        guard !isScanning else { return }

        isScanning = true
        scanResults.removeAll()

        let items = patchStore.items

        DispatchQueue.global(qos: .userInitiated).async {
            var results: [String] = []

            for item in items {
                let url = item.packageURL
                let filename = url.lastPathComponent

                guard FileManager.default.fileExists(
                    atPath: url.path
                ) else {
                    results.append("MISSING FILE: \(filename)")
                    continue
                }

                do {
                    let attributes = try FileManager.default.attributesOfItem(
                        atPath: url.path
                    )

                    let size = attributes[.size] as? NSNumber ?? 0

                    if size.intValue <= 0 {
                        results.append("EMPTY FILE: \(filename)")
                        continue
                    }

                    let data = try Data(contentsOf: url)
                    let digest = SHA256.hash(data: data)
                    let checksum = digest.map {
                        String(format: "%02x", $0)
                    }.joined()

                    results.append(
                        "OK: \(filename) • \(size.intValue) bytes • SHA256 \(String(checksum.prefix(12)))"
                    )

                } catch {
                    results.append(
                        "READ ERROR: \(filename) • \(error.localizedDescription)"
                    )
                }
            }

            DispatchQueue.main.async {
                scanResults = results
                isScanning = false

                let failed = results.filter {
                    $0.hasPrefix("MISSING") ||
                    $0.hasPrefix("EMPTY") ||
                    $0.hasPrefix("READ ERROR")
                }.count

                setStatus(
                    failed == 0
                    ? "Security scan completed"
                    : "Security scan found \(failed) issue(s)",
                    failed == 0 ? .success : .warning
                )

                addNotification("Security scan completed")
            }
        }
    }

    // MARK: File Information

    private func formattedSize(_ number: NSNumber?) -> String {
        guard let number else { return "Unknown" }

        return ByteCountFormatter.string(
            fromByteCount: number.int64Value,
            countStyle: .file
        )
    }

    // MARK: Names & Colors

    private func getDefaultName(for filename: String) -> String {
        if filename.contains("(20)") { return "AimBody" }
        if filename.contains("(21)") { return "AimLock" }
        if filename.contains("(22)") { return "Antiban" }
        if filename.contains("(23)") { return "Nhẹ Tâm" }

        return filename
            .replacingOccurrences(of: "NOX File (", with: "Patch ")
            .replacingOccurrences(of: ").3105", with: "")
    }

    private func getColorForPatch(_ filename: String) -> Color {
        if filename.contains("(20)") { return Premium.gold }
        if filename.contains("(21)") { return Premium.goldLight }
        if filename.contains("(22)") { return Premium.green }
        if filename.contains("(23)") { return Premium.orange }

        return .cyan
    }

    private func getIconForPatch(_ filename: String) -> String {
        if filename.contains("(20)") { return "scope" }
        if filename.contains("(21)") { return "target" }
        if filename.contains("(22)") { return "shield.lefthalf.filled" }
        if filename.contains("(23)") { return "hand.raised.fill" }

        return "bolt.fill"
    }

    // MARK: Helpers

    private func setStatus(
        _ text: String,
        _ kind: StatusKind
    ) {
        status = StatusMessage(text: text, kind: kind)
    }

    private func addNotification(_ message: String) {
        notifications.insert(message, at: 0)

        if notifications.count > 50 {
            notifications = Array(notifications.prefix(50))
        }
    }

    private func haptic(
        _ type: UINotificationFeedbackGenerator.FeedbackType
    ) {
        UINotificationFeedbackGenerator()
            .notificationOccurred(type)
    }

    // MARK: Launch Game

    private func launchGame() {
        guard let url = URL(string: "freefireth://") else {
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            DispatchQueue.main.async {
                if !success {
                    setStatus(
                        "Không mở được Free Fire — kiểm tra game đã cài chưa",
                        .error
                    )

                    haptic(.error)
                }
            }
        }
    }

    // MARK: Sync Patch States

    private func syncPatchStates() {
        var states: [String: Bool] = [:]

        for item in patchStore.items {
            states[item.packageURL.lastPathComponent] =
                DevicePatchService.latestReceipt(projectID: item.id) != nil
        }

        patchStates = states
    }

    // MARK: Patch Results

    private enum PatchActionResult {
        case applied
        case restored
        case needsPassword
        case failed(String)
    }

    // MARK: Toggle Patch

    private func togglePatch(packageFilename: String) {
        guard !patchOperationBusy else { return }

        guard let item = patchStore.items.first(where: {
            $0.packageURL.lastPathComponent.caseInsensitiveCompare(
                packageFilename
            ) == .orderedSame
        }) else {
            return
        }

        patchOperationBusy = true

        let project = item.project
        let projectID = item.id

        DispatchQueue.global(qos: .userInitiated).async {
            let result: PatchActionResult

            if let receipt = DevicePatchService.latestReceipt(
                projectID: projectID
            ) {
                do {
                    try DevicePatchService.restore(receipt: receipt)
                    result = .restored
                } catch {
                    result = .failed(
                        "RESTORE FAILED — \(error.localizedDescription)"
                    )
                }

            } else if let project {
                do {
                    _ = try DevicePatchService.apply(project: project)
                    result = .applied
                } catch {
                    result = .failed(
                        "APPLY FAILED — \(error.localizedDescription)"
                    )
                }

            } else {
                result = .needsPassword
            }

            let isActiveNow =
                DevicePatchService.latestReceipt(projectID: projectID) != nil

            DispatchQueue.main.async {
                patchStates[packageFilename] = isActiveNow

                switch result {
                case .applied:
                    applyCount += 1
                    setStatus(
                        "Inject Successful — \(packageFilename)",
                        .success
                    )
                    addNotification("Apply thành công: \(packageFilename)")
                    haptic(.success)

                case .restored:
                    restoreCount += 1
                    setStatus(
                        "Restore Successful — \(packageFilename)",
                        .success
                    )
                    addNotification("Restore thành công: \(packageFilename)")
                    haptic(.success)

                case .needsPassword:
                    patchStore.requestUnlock(for: item)
                    setStatus("PASSWORD REQUIRED", .warning)
                    haptic(.warning)

                case .failed(let message):
                    errorCount += 1
                    setStatus(message, .error)
                    addNotification("Lỗi thao tác: \(packageFilename)")
                    haptic(.error)
                }

                patchOperationBusy = false
            }
        }
    }

    // MARK: Disable All

    private func disableAll() {
        guard !patchOperationBusy else { return }

        let targets: [
            (filename: String, id: PatchLibraryItem.ID)
        ] = patchStore.items.map {
            ($0.packageURL.lastPathComponent, $0.id)
        }

        patchOperationBusy = true

        DispatchQueue.global(qos: .userInitiated).async {
            var restored = 0
            var failed = 0

            for target in targets {
                guard let receipt = DevicePatchService.latestReceipt(
                    projectID: target.id
                ) else {
                    continue
                }

                do {
                    try DevicePatchService.restore(receipt: receipt)
                    restored += 1
                } catch {
                    failed += 1
                }
            }

            var states: [String: Bool] = [:]

            for target in targets {
                states[target.filename] =
                    DevicePatchService.latestReceipt(projectID: target.id) != nil
            }

            DispatchQueue.main.async {
                patchStates = states

                restoreCount += restored
                errorCount += failed

                if failed == 0 {
                    setStatus("Đã tắt \(restored) patch", .success)
                    addNotification("Đã khôi phục \(restored) patch")
                    haptic(.success)
                } else {
                    setStatus(
                        "Tắt \(restored) patch, \(failed) lỗi",
                        .error
                    )
                    haptic(.error)
                }

                patchOperationBusy = false
            }
        }
    }
}

// MARK: - Premium View Modifier

private struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.cyan.opacity(0.42), Color.blue.opacity(0.14), Color.cyan.opacity(0.25)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.cyan.opacity(0.055), radius: 14, y: 5)
    }
}

private extension View {
    func premiumCard() -> some View {
        modifier(PremiumCardModifier())
    }
}

// MARK: - Premium Button Animation

private struct PremiumPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(
                .spring(response: 0.25, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}
