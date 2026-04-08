import Foundation
import PromisoShared

// MARK: - Response DTOs

private struct RustSettingsResponse: Decodable {
  let notificationEnabled: Bool?
  let groupSortType: String
  let groupSortOrder: [String]?
  let conflictThresholdMin: Int
  let briefing: RustBriefingSettings
}

private struct RustBriefingSettings: Decodable {
  let style: String?
  let notificationHour: Int?
  let timezone: String?
  let language: String?
  let availableTransports: [String]
  let defaultLocation: RustDefaultLocation?
}

private struct RustDefaultLocation: Decodable {
  let name: String
  let address: String?
  let latitude: Double?
  let longitude: Double?
}

// MARK: - Request DTOs

private struct PatchGroupSortBody: Encodable {
  let groupSortType: String
  let groupSortOrder: [String]?
}

private struct PatchConflictThresholdBody: Encodable {
  let conflictThresholdMin: Int
}

private struct PatchBriefingStyleBody: Encodable {
  let briefingStyle: String
}

private struct PatchBriefingNotificationHourBody: Encodable {
  let briefingNotificationHour: Int?
  let briefingTimezone: String?
  let briefingLanguage: String?
}

private struct PatchAvailableTransportsBody: Encodable {
  let briefingAvailableTransports: [String]
}

private struct PatchBriefingDefaultLocationBody: Encodable {
  let briefingDefaultLocation: PatchLocationBody?
}

private struct PatchLocationBody: Encodable {
  let name: String
  let address: String?
  let latitude: Double?
  let longitude: Double?
}

private struct RustSuccess: Decodable {
  let success: Bool?
}

// MARK: - Data Source

/// Rust 백엔드를 통한 사용자 설정 데이터 관리
public actor UserSettingsRustDataSource {
  private let api: RustAPIClient

  public init(api: RustAPIClient) {
    self.api = api
  }

  // MARK: - Settings Operations

  /// 사용자 설정 조회
  public func fetchSettings(userId: String) async throws -> UserSettings {
    let response: RustSettingsResponse = try await api.get("/api/v1/users/me/settings")
    return response.toModel()
  }

  /// Pro 설정 존재 여부 확인 (Rust에서는 설정이 항상 존재하므로 true 반환)
  public func hasProSettings(userId: String) async throws -> Bool {
    let response: RustSettingsResponse = try await api.get("/api/v1/users/me/settings")
    // conflictThresholdMin이 0보다 크거나 briefing 스타일이 설정된 경우 Pro 설정 존재로 판단
    return response.conflictThresholdMin > 0 || response.briefing.style != nil
  }

  /// 그룹 정렬 옵션 업데이트
  public func updateGroupSortOption(userId: String, option: GroupSortOption) async throws {
    let body = PatchGroupSortBody(
      groupSortType: option.sortType.rawValue,
      groupSortOrder: option.sortType == .custom ? option.customOrder : nil
    )
    let _: RustSuccess = try await api.patch("/api/v1/users/me/settings", body: body)
  }

  /// 일정 충돌 감지 임계값 업데이트
  public func updateConflictDetectionThreshold(userId: String, threshold: Int) async throws {
    let body = PatchConflictThresholdBody(conflictThresholdMin: threshold)
    let _: RustSuccess = try await api.patch("/api/v1/users/me/settings", body: body)
  }

  /// 브리핑 스타일 업데이트
  public func updateBriefingStyle(userId: String, style: BriefingStyle) async throws {
    let body = PatchBriefingStyleBody(briefingStyle: style.rawValue)
    let _: RustSuccess = try await api.patch("/api/v1/users/me/settings", body: body)
  }

  /// 브리핑 알림 시간 업데이트
  public func updateBriefingNotificationHour(userId: String, hour: Int?) async throws {
    let body = PatchBriefingNotificationHourBody(
      briefingNotificationHour: hour,
      briefingTimezone: hour != nil ? TimeZone.current.identifier : nil,
      briefingLanguage: hour != nil ? AppLanguage.resolved.rawValue : nil
    )
    let _: RustSuccess = try await api.patch("/api/v1/users/me/settings", body: body)
  }

  /// 이용 가능 교통수단 업데이트
  public func updateAvailableTransports(userId: String, transports: Set<AvailableTransport>) async throws {
    let body = PatchAvailableTransportsBody(
      briefingAvailableTransports: transports.map(\.rawValue).sorted()
    )
    let _: RustSuccess = try await api.patch("/api/v1/users/me/settings", body: body)
  }

  /// 브리핑 기본 위치 업데이트
  public func updateBriefingDefaultLocation(userId: String, location: LocationInfoModel?) async throws {
    let locationBody = location.map {
      PatchLocationBody(
        name: $0.name,
        address: $0.address,
        latitude: $0.latitude,
        longitude: $0.longitude
      )
    }
    let body = PatchBriefingDefaultLocationBody(briefingDefaultLocation: locationBody)
    let _: RustSuccess = try await api.patch("/api/v1/users/me/settings", body: body)
  }

  /// Pro 가입 시 기본 설정값 초기화
  public func initializeProDefaults(userId: String) async throws {
    let _: RustSuccess = try await api.post(
      "/api/v1/users/me/settings/initialize-pro",
      body: InitializeProBody(timezone: TimeZone.current.identifier)
    )
  }
}

private struct InitializeProBody: Encodable {
  let timezone: String
}

// MARK: - DTO → Model 변환

extension RustSettingsResponse {
  func toModel() -> UserSettings {
    let groupSortOption: GroupSortOption = {
      switch groupSortType {
      case "joinedRecent":
        return .joinedRecent
      case "joinedOldest":
        return .joinedOldest
      case "nameAscending":
        return .nameAscending
      case "nameDescending":
        return .nameDescending
      case "custom":
        return .custom(order: groupSortOrder ?? [])
      default:
        return .joinedRecent
      }
    }()

    let briefingStyleValue = briefing.style.flatMap { BriefingStyle(rawValue: $0) } ?? .friendly
    let transports: Set<AvailableTransport> = {
      let mapped = Set(briefing.availableTransports.compactMap { AvailableTransport(rawValue: $0) })
      return mapped.isEmpty ? [.transit, .car] : mapped
    }()

    let defaultLocation: LocationInfoModel? = briefing.defaultLocation.map {
      LocationInfoModel(
        name: $0.name,
        address: $0.address,
        latitude: $0.latitude,
        longitude: $0.longitude
      )
    }

    return UserSettings(
      notificationEnabled: notificationEnabled ?? true,
      groupSortOption: groupSortOption,
      conflictDetectionThreshold: conflictThresholdMin,
      briefingStyle: briefingStyleValue,
      briefingNotificationHour: briefing.notificationHour,
      availableTransports: transports,
      briefingDefaultLocation: defaultLocation
    )
  }
}
