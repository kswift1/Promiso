import ComposableArchitecture
import CoreLocation
import Foundation
import PromisoShared

// MARK: - Error

/// 일정 추출 API 에러
public enum ScheduleExtractionError: Error, Equatable {
  case notAuthenticated
  case networkError
  case invalidResponse
  case serverError(String)
  case textTooLong
  case emptyText
  case imageTooLarge

  public var localizedDescription: String {
    switch self {
    case .notAuthenticated:
      return LocalizedStrings.Error.userAuthRequired
    case .networkError:
      return LocalizedStrings.Error.networkError
    case .invalidResponse:
      return LocalizedStrings.Error.invalidResponse
    case .serverError(let message):
      return LocalizedStrings.Error.serverErrorWithMessage(message)
    case .textTooLong:
      return LocalizedStrings.Error.textTooLong
    case .emptyText:
      return LocalizedStrings.Error.emptyText
    case .imageTooLarge:
      return LocalizedStrings.Error.imageTooLarge
    }
  }
}

// MARK: - Client

/// 텍스트/이미지에서 일정 정보를 추출하는 Client (LLM 기반)
@DependencyClient
public struct ScheduleExtractionClient: Sendable {
  /// 텍스트에서 일정 정보 추출 (Rust API 호출)
  public var extractFromText: @Sendable (_ text: String) async throws -> PersonalEventModel
  /// 이미지에서 일정 정보 추출 (Rust API 호출, base64 인코딩)
  public var extractFromImage: @Sendable (_ imageData: Data) async throws -> PersonalEventModel
}

// MARK: - Test & Preview Values

extension ScheduleExtractionClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    extractFromText: { _ in
      try await Task.sleep(for: .seconds(1))
      return PersonalEventModel(
        title: "주말 모임",
        descriptionBlocks: [
          DescriptionBlock(content: .text("회비: 1인당 30,000원")),
          DescriptionBlock(content: .checklist([
            ChecklistItem(text: "보드게임"),
            ChecklistItem(text: "간식"),
          ])),
        ],
        startAt: Date().addingTimeInterval(86400),
        location: LocationInfoModel(name: "강남역")
      )
    },
    extractFromImage: { _ in
      try await Task.sleep(for: .seconds(1))
      return PersonalEventModel(
        title: "주말 모임",
        descriptionBlocks: [
          DescriptionBlock(content: .text("회비: 1인당 30,000원")),
          DescriptionBlock(content: .checklist([
            ChecklistItem(text: "보드게임"),
            ChecklistItem(text: "간식"),
          ])),
        ],
        startAt: Date().addingTimeInterval(86400),
        location: LocationInfoModel(name: "강남역")
      )
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var scheduleExtractionClient: ScheduleExtractionClient {
    get { self[ScheduleExtractionClient.self] }
    set { self[ScheduleExtractionClient.self] = newValue }
  }
}

// MARK: - ISO 8601 Parsing Helpers

private extension ISO8601DateFormatter {
  /// Gemini가 반환하는 다양한 ISO 8601 포맷을 파싱 (fractionalSeconds 포함)
  static let flexible: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  /// fractionalSeconds 없는 표준 버전
  static let standard: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
}

/// ISO 8601 문자열을 Date로 파싱 (여러 포맷 시도)
private func parseISO8601Date(_ string: String) -> Date? {
  if let date = ISO8601DateFormatter.flexible.date(from: string) {
    return date
  }
  if let date = ISO8601DateFormatter.standard.date(from: string) {
    return date
  }
  // "2026-03-27T09:00:00+09:00" 형식도 처리
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
  formatter.locale = Locale(identifier: "en_US_POSIX")
  return formatter.date(from: string)
}

private struct RustExtractScheduleBody: Encodable {
  let text: String?
  let imageBase64: String?
  let timezone: String
}

private struct RustExtractScheduleResponse: Decodable {
  let title: String?
  let emoji: String?
  let startDate: String?
  let endDate: String?
  let location: String?
  let address: String?
  let description: String?
  let descriptionBlocks: [RustDescriptionBlock]?
}

private struct RustDescriptionBlock: Decodable {
  let type: String
  let content: String?
  let items: [String]?
}

// MARK: - Live Implementation

extension ScheduleExtractionClient: DependencyKey {
  public static let liveValue: ScheduleExtractionClient = {
    let rustClient = RustAPIClient()

    return Self(
      extractFromText: { text in
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
          throw ScheduleExtractionError.emptyText
        }
        guard trimmedText.count <= 2000 else {
          throw ScheduleExtractionError.textTooLong
        }

        AppLogger.general.debug("📋 [ScheduleExtraction] 일정 추출 시작 (\(trimmedText.count)자)")
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
          let response: RustExtractScheduleResponse = try await rustClient.post(
            "/api/v1/schedules/extract",
            body: RustExtractScheduleBody(
              text: trimmedText,
              imageBase64: nil,
              timezone: TimeZone.current.identifier
            )
          )

          let totalTime = CFAbsoluteTimeGetCurrent() - startTime
          AppLogger.general.info("✅ [ScheduleExtraction] Rust 추출 완료 (소요: \(String(format: "%.2f", totalTime))초)")

          let event = try parseEventModel(from: response)
          return await geocodeIfNeeded(event)
        } catch let error as ScheduleExtractionError {
          throw error
        } catch let error as RustAPIError {
          let totalTime = CFAbsoluteTimeGetCurrent() - startTime
          AppLogger.general.error("❌ [ScheduleExtraction] 에러: \(error.localizedDescription) (소요: \(String(format: "%.2f", totalTime))초)")

          switch error {
          case .serverError(let code, let message):
            switch code {
            case "unauthenticated":
              throw ScheduleExtractionError.notAuthenticated
            case "invalid-argument":
              throw ScheduleExtractionError.invalidResponse
            default:
              throw ScheduleExtractionError.serverError(message)
            }
          default:
            throw ScheduleExtractionError.networkError
          }
        } catch {
          throw ScheduleExtractionError.networkError
        }
      },
      extractFromImage: { imageData in
        // 4MB 제한
        guard imageData.count <= 4 * 1024 * 1024 else {
          throw ScheduleExtractionError.imageTooLarge
        }

        let base64String = imageData.base64EncodedString()
        AppLogger.general.debug("📸 [ScheduleExtraction] 이미지 추출 시작 (\(imageData.count) bytes)")
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
          let response: RustExtractScheduleResponse = try await rustClient.post(
            "/api/v1/schedules/extract",
            body: RustExtractScheduleBody(
              text: nil,
              imageBase64: base64String,
              timezone: TimeZone.current.identifier
            )
          )

          let totalTime = CFAbsoluteTimeGetCurrent() - startTime
          AppLogger.general.info("✅ [ScheduleExtraction] Rust 이미지 추출 완료 (소요: \(String(format: "%.2f", totalTime))초)")

          let event = try parseEventModel(from: response)
          return await geocodeIfNeeded(event)
        } catch let error as ScheduleExtractionError {
          throw error
        } catch let error as RustAPIError {
          let totalTime = CFAbsoluteTimeGetCurrent() - startTime
          AppLogger.general.error("❌ [ScheduleExtraction] 이미지 에러: \(error.localizedDescription) (소요: \(String(format: "%.2f", totalTime))초)")

          switch error {
          case .serverError(let code, let message):
            switch code {
            case "unauthenticated":
              throw ScheduleExtractionError.notAuthenticated
            case "invalid-argument":
              throw ScheduleExtractionError.invalidResponse
            default:
              throw ScheduleExtractionError.serverError(message)
            }
          default:
            throw ScheduleExtractionError.networkError
          }
        } catch {
          throw ScheduleExtractionError.networkError
        }
      }
    )
  }()
}

// MARK: - Response Parsing

private func parseEventModel(from response: RustExtractScheduleResponse) throws -> PersonalEventModel {
  var event = PersonalEventModel()

  if let title = response.title, !title.isEmpty {
    event.title = String(title.prefix(30))
  }

  if let emoji = response.emoji, !emoji.isEmpty {
    event.emoji = String(emoji.prefix(1))
  }

  if let startDateStr = response.startDate,
     let startDate = parseISO8601Date(startDateStr) {
    event.startAt = startDate
  }

  if let endDateStr = response.endDate,
     let endDate = parseISO8601Date(endDateStr) {
    event.endAt = endDate
  }

  if let locationName = response.location, !locationName.isEmpty {
    event.location = LocationInfoModel(
      name: locationName,
      address: response.address
    )
  }

  // First try structured blocks
  if let blocksData = response.descriptionBlocks {
    let blocks = blocksData.compactMap { blockData -> DescriptionBlock? in
      switch blockData.type {
      case "text":
        guard let content = blockData.content, !content.isEmpty else { return nil }
        return DescriptionBlock(content: .text(content))
      case "checklist":
        guard let items = blockData.items, !items.isEmpty else { return nil }
        return DescriptionBlock(content: .checklist(items.map { ChecklistItem(text: $0) }))
      case "bulletList":
        guard let items = blockData.items, !items.isEmpty else { return nil }
        return DescriptionBlock(content: .bulletList(items))
      default:
        return nil
      }
    }
    if !blocks.isEmpty {
      event.descriptionBlocks = blocks.mergingAdjacentTextBlocks()
      event.description = event.descriptionBlocks.plainText
    }
  }

  // Fallback: plain description → wrap in text block
  if event.descriptionBlocks.isEmpty,
     let description = response.description,
     !description.isEmpty {
    let trimmed = String(description.prefix(500))
    event.description = trimmed
    event.descriptionBlocks = [DescriptionBlock(content: .text(trimmed))]
  }

  return event
}

/// 주소 텍스트 → CLGeocoder로 좌표 변환
/// 성공 시 LocationInfoModel에 좌표 설정, 실패 시 location 제거하고 description에 장소 정보 추가
private func geocodeIfNeeded(_ event: PersonalEventModel) async -> PersonalEventModel {
  guard let location = event.location,
        location.latitude == nil else {
    return event
  }

  // 주소 또는 장소명으로 geocoding 시도
  let query = location.address ?? location.name
  do {
    let placemarks = try await CLGeocoder().geocodeAddressString(query)
    if let coordinate = placemarks.first?.location?.coordinate {
      var updated = event
      updated.location = LocationInfoModel(
        name: location.name,
        address: location.address,
        latitude: coordinate.latitude,
        longitude: coordinate.longitude
      )
      AppLogger.general.info("📍 [Geocoding] \(query) → (\(coordinate.latitude), \(coordinate.longitude))")
      return updated
    }
  } catch {
    AppLogger.general.warning("📍 [Geocoding] 실패: \(error.localizedDescription)")
  }

  // 좌표 변환 실패 → location 제거, descriptionBlocks에 장소 정보 추가
  var updated = event
  updated.location = nil
  let locationText = [location.name, location.address]
    .compactMap { $0 }.joined(separator: " ")
  if !locationText.isEmpty {
    let locationBlock = DescriptionBlock(
      content: .text("장소: \(locationText)")
    )
    updated.descriptionBlocks.insert(locationBlock, at: 0)
    updated.description = updated.descriptionBlocks.plainText
  }
  AppLogger.general.info("📍 [Geocoding] 좌표 변환 실패 → description으로 이동: \(locationText)")
  return updated
}
