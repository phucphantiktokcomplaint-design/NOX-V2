import Combine
import Foundation
import Security
import UIKit

@MainActor
final class LicenseManager: ObservableObject {
    private let apiURL = URL(string: "https://6a1e0052bcc4f20d5ca543e1.mockapi.io/api/v1/key")!
    private let configRecordKey = "NOX_SYSTEM_CONFIG"

    @Published private(set) var expirationDate: Date? = nil
    @Published private(set) var isActive = false
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var contactOwner: String? = "0964943392"
    @Published var rememberKey = true
    @Published var forceLogout = false
    @Published var announcement: Announcement? = nil

    private let keychain = Keychain(service: "com.felixphan.nox.activation")
    private let keyAccount = "license-key"
    private var currentKey: String?

    init() {
        currentKey = keychain.string(keyAccount)
        // Không tin trạng thái kích hoạt lưu cục bộ: luôn xác minh lại với server.
        isActive = false
    }

    var hasRememberedKey: Bool { !(keychain.string(keyAccount) ?? "").isEmpty }
    func rememberedKey() -> String? { currentKey ?? keychain.string(keyAccount) }

    func refresh() {
        Task { await checkSession() }
    }

    /// Gọi khi mở app. Maintenance được kiểm tra trước khi xác minh key đã lưu.
    func beginLaunchSession() {
        currentKey = keychain.string(keyAccount)
        isActive = false
        forceLogout = false
        Task {
            await checkSession()
            if !isActive && message == nil { message = "Nhập key để tiếp tục" }
        }
    }

    /// Xác minh key đã lưu mỗi khi app trở lại foreground.
    func checkSession() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let records = try await fetchRecords()
            if isMaintenanceEnabled(in: records) {
                rejectForMaintenance()
                return
            }
            guard let saved = currentKey ?? keychain.string(keyAccount), !saved.isEmpty else {
                isActive = false
                message = "Nhập key để tiếp tục"
                return
            }
            try validateExistingKey(saved, records: records)
            currentKey = saved
            isActive = true
            forceLogout = false
            message = "NOX V2 đã sẵn sàng — FELIX PHAN"
        } catch let error as LicenseError {
            isActive = false
            forceLogout = true
            message = error.message
        } catch {
            isActive = false
            message = "Không thể kết nối máy chủ xác thực. Vui lòng thử lại."
        }
    }

    func activate(key: String) {
        guard !isBusy else { return }
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            message = "Vui lòng nhập license key"
            return
        }
        Task { await activateOnline(key: normalized) }
    }

    private func activateOnline(key: String) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let records = try await fetchRecords()
            if isMaintenanceEnabled(in: records) {
                rejectForMaintenance()
                return
            }
            guard let index = records.firstIndex(where: {
                string($0["key"]) == key && string($0["key"]) != configRecordKey
            }) else {
                throw LicenseError(message: "Key không tồn tại trên máy chủ")
            }

            var record = records[index]
            let recordID = string(record["id"])
            guard !recordID.isEmpty else {
                throw LicenseError(message: "Dữ liệu key trên server thiếu ID")
            }

            let deviceID = DeviceID.current
            guard deviceID != "Unavailable" else {
                throw LicenseError(message: "Không thể đọc Device ID của thiết bị")
            }
            let status = string(record["status"]).lowercased()
            let boundDevice = string(record["deviceId"])
            let revokedAt = string(record["revokedAt"])

            guard revokedAt.isEmpty || revokedAt.lowercased() == "null" else {
                throw LicenseError(message: "Key đã bị thu hồi")
            }
            guard status != "revoked", status != "expired" else {
                throw LicenseError(message: status == "expired" ? "Key đã hết hạn" : "Key đã bị thu hồi")
            }
            if !boundDevice.isEmpty && boundDevice != "null" && boundDevice != deviceID {
                throw LicenseError(message: "Key đã được kích hoạt trên thiết bị khác", isConflict: true)
            }

            let now = Date()
            let expiresAt: Date
            if status == "active" {
                guard let existingExpiry = parseDate(record["expiresAt"]) else {
                    throw LicenseError(message: "Key trên server thiếu thời hạn hợp lệ")
                }
                guard existingExpiry > now else {
                    throw LicenseError(message: "Key đã hết hạn")
                }
                expiresAt = existingExpiry
            } else if status == "unused" {
                guard let duration = number(record["durationSeconds"]), duration > 0 else {
                    throw LicenseError(message: "Key trên server thiếu thời lượng hợp lệ")
                }
                expiresAt = now.addingTimeInterval(duration)
                record["deviceId"] = deviceID
                record["activatedAt"] = isoString(now)
                record["expiresAt"] = isoString(expiresAt)
                record["status"] = "active"
                try await updateRecord(id: recordID, body: record)
            } else {
                throw LicenseError(message: "Trạng thái key không hợp lệ: \(status)")
            }

            currentKey = key
            if rememberKey {
                keychain.save(key, account: keyAccount)
            } else {
                keychain.delete(keyAccount)
            }
            expirationDate = expiresAt
            isActive = true
            forceLogout = false
            message = "Kích hoạt thành công — chào mừng đến NOX V2"
        } catch let error as LicenseError {
            isActive = false
            message = error.message
        } catch {
            isActive = false
            message = "Không thể kết nối hoặc cập nhật key trên server. Vui lòng thử lại."
        }
    }

    func deactivate() {
        keychain.delete(keyAccount)
        currentKey = nil
        isActive = false
        expirationDate = nil
        forceLogout = false
        message = "Đã xoá kích hoạt"
    }

    private func fetchRecords() async throws -> [[String: Any]] {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LicenseError(message: "Máy chủ xác thực trả về lỗi")
        }
        guard let records = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw LicenseError(message: "Dữ liệu key từ server không hợp lệ")
        }
        return records
    }

    private func updateRecord(id: String, body: [String: Any]) async throws {
        let url = apiURL.appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw LicenseError(message: "Không thể ghi nhận Device ID lên server. \(detail)")
        }
    }

    private func validateExistingKey(_ key: String, records: [[String: Any]]) throws {
        if isMaintenanceEnabled(in: records) {
            throw LicenseError(message: "NOX đang bảo trì. Vui lòng quay lại sau.")
        }
        guard let record = records.first(where: { string($0["key"]) == key }) else {
            throw LicenseError(message: "Key không còn tồn tại trên server")
        }
        let status = string(record["status"]).lowercased()
        guard status == "active" else {
            throw LicenseError(message: status == "expired" ? "Key đã hết hạn" : "Key không còn hiệu lực")
        }
        guard string(record["deviceId"]) == DeviceID.current else {
            throw LicenseError(message: "Key đã được kích hoạt trên thiết bị khác", isConflict: true)
        }
        guard let expiry = parseDate(record["expiresAt"]), expiry > Date() else {
            throw LicenseError(message: "Key đã hết hạn hoặc thời hạn không hợp lệ")
        }
        expirationDate = expiry
    }

    /// Cấu hình bảo trì là một record trong cùng resource /key, có key = NOX_SYSTEM_CONFIG.
    private func isMaintenanceEnabled(in records: [[String: Any]]) -> Bool {
        guard let config = records.first(where: { string($0["key"]) == configRecordKey }) else {
            return false
        }
        if let value = config["maintenance"] as? Bool { return value }
        return ["true", "1", "yes", "on"].contains(string(config["maintenance"]).lowercased())
    }

    private func rejectForMaintenance() {
        isActive = false
        forceLogout = true
        message = "NOX đang bảo trì. Vui lòng quay lại sau."
    }

    private func string(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        return String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func number(_ value: Any?) -> TimeInterval? {
        if let value = value as? NSNumber { return value.doubleValue }
        return Double(string(value))
    }

    private func parseDate(_ value: Any?) -> Date? {
        let raw = string(value)
        guard !raw.isEmpty, raw.lowercased() != "null" else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        let standard = ISO8601DateFormatter()
        return standard.date(from: raw)
    }

    private func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

struct Announcement: Codable, Identifiable {
    var id: String { date + title }
    let title: String
    let message: String
    let date: String
    let isUrgent: Bool
}

struct LicenseError: Error {
    let message: String
    var isConflict = false
    init(message: String, isConflict: Bool = false) {
        self.message = message
        self.isConflict = isConflict
    }
}

struct Keychain {
    let service: String
    private func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    func string(_ account: String) -> String? {
        var q = base(account); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let status = SecItemUpdate(base(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = base(account); item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }
    func delete(_ account: String) { SecItemDelete(base(account) as CFDictionary) }
}
