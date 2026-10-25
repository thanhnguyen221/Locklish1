import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
import SwiftUI

// MARK: - CloudSyncService
/// Thin wrapper reporting the CloudKit account status for the sync indicator
/// in Settings. The actual sync is driven by SwiftData's CloudKit integration
/// (ModelContainer + iCloud entitlements) — nothing to orchestrate manually.
///
/// PERSONAL_BUILD: the free-account build has NO iCloud entitlements, and
/// creating a CKContainer for an unentitled identifier traps at runtime —
/// so CloudKit is never touched there and the card reports local-only mode.
@Observable
@MainActor
final class CloudSyncService {
    static let shared = CloudSyncService()

    enum SyncStatus: Equatable {
        case syncing          // signed in — everything mirrors to iCloud
        case signedOut        // device not signed into iCloud
        case restricted       // parental control / managed restriction
        case temporarilyUnavailable
        case localOnly        // Personal build — no iCloud capability at all
        case unknown
    }

    private(set) var status: SyncStatus = .unknown

    private init() {}

    func refreshStatus() async {
        #if PERSONAL_BUILD
        status = .localOnly
        #else
        do {
            let account = try await CKContainer(identifier: "iCloud.com.locklish.app").accountStatus()
            switch account {
            case .available: status = .syncing
            case .noAccount: status = .signedOut
            case .restricted: status = .restricted
            case .couldNotDetermine, .temporarilyUnavailable: status = .temporarilyUnavailable
            @unknown default: status = .unknown
            }
        } catch {
            status = .unknown
        }
        #endif
    }

    var statusTitle: String {
        switch status {
        case .syncing: return "Đang đồng bộ iCloud"
        case .signedOut: return "Chưa đăng nhập iCloud"
        case .restricted: return "Tài khoản bị hạn chế"
        case .temporarilyUnavailable: return "iCloud tạm thời không khả dụng"
        case .localOnly: return "Chế độ cá nhân — không đồng bộ"
        case .unknown: return "Đang kiểm tra iCloud…"
        }
    }

    var statusDetail: String {
        switch status {
        case .syncing:
            return "Từ vựng, folder và tiến trình ôn tập (SM-2) tự động theo bạn qua mọi thiết bị đăng nhập cùng Apple ID."
        case .signedOut:
            return "Đăng nhập iCloud trong Cài đặt hệ thống (Apps → iCloud) để bật đồng bộ. Dữ liệu vẫn lưu an toàn trên máy."
        case .restricted:
            return "Tài khoản iCloud đang bị hạn chế. Liên hệ người quản lý để mở khóa đồng bộ."
        case .temporarilyUnavailable:
            return "Không kiểm tra được trạng thái iCloud. Dữ liệu vẫn lưu trên máy — thử lại sau."
        case .localOnly:
            return "Bản xây dựng cá nhân (miễn phí) không có iCloud. Dữ liệu lưu an toàn trên máy — đồng bộ sẽ bật khi dùng tài khoản Developer."
        case .unknown:
            return "Đang xác minh kết nối iCloud…"
        }
    }

    var statusColor: Color {
        switch status {
        case .syncing: return AppTheme.success
        case .signedOut: return AppTheme.warning
        default: return AppTheme.textTertiary
        }
    }
}
