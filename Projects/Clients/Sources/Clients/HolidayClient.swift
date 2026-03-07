import ComposableArchitecture
import Foundation
import os.log

// MARK: - Public Holiday Model

public struct PublicHoliday: Equatable, Sendable, Codable {
  public let date: Date
  public let localName: String
  public let name: String

  public init(date: Date, localName: String, name: String) {
    self.date = date
    self.localName = localName
    self.name = name
  }
}

// MARK: - HolidayClient

@DependencyClient
public struct HolidayClient: Sendable {
  /// 특정 연도의 공휴일 조회
  public var fetchHolidays: @Sendable (_ year: Int) async throws -> [PublicHoliday]
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var holidayClient: HolidayClient {
    get { self[HolidayClient.self] }
    set { self[HolidayClient.self] = newValue }
  }
}

// MARK: - Test / Preview

extension HolidayClient: TestDependencyKey {
  public static let previewValue = Self(
    fetchHolidays: { year in
      // 미리보기용 샘플 공휴일 (대체공휴일 포함)
      guard let koreaTimeZone = TimeZone(identifier: "Asia/Seoul") else {
        fatalError("Could not create Asia/Seoul timezone for preview.")
      }
      var koreaCalendar = Calendar(identifier: .gregorian)
      koreaCalendar.timeZone = koreaTimeZone

      func makeDate(month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return koreaCalendar.date(from: c) ?? Date()
      }

      return [
        PublicHoliday(date: makeDate(month: 1, day: 1), localName: "새해", name: "새해"),
        PublicHoliday(date: makeDate(month: 3, day: 1), localName: "삼일절", name: "삼일절"),
        PublicHoliday(date: makeDate(month: 5, day: 5), localName: "어린이날", name: "어린이날"),
        PublicHoliday(date: makeDate(month: 5, day: 6), localName: "대체공휴일(어린이날)", name: "대체공휴일(어린이날)"),
        PublicHoliday(date: makeDate(month: 6, day: 6), localName: "현충일", name: "현충일"),
        PublicHoliday(date: makeDate(month: 8, day: 15), localName: "광복절", name: "광복절"),
        PublicHoliday(date: makeDate(month: 10, day: 3), localName: "개천절", name: "개천절"),
        PublicHoliday(date: makeDate(month: 10, day: 9), localName: "한글날", name: "한글날"),
        PublicHoliday(date: makeDate(month: 12, day: 25), localName: "크리스마스", name: "크리스마스"),
      ]
    }
  )

  public static let testValue = Self(
    fetchHolidays: { _ in [] }
  )
}

// MARK: - Live Implementation

extension HolidayClient: DependencyKey {
  public static let liveValue: HolidayClient = {
    let cache = HolidayCache()

    return Self(
      fetchHolidays: { year in
        try await cache.fetchHolidays(for: year)
      }
    )
  }()
}

// MARK: - Holiday Cache (Actor)

private struct CachedHolidays: Codable {
  let fetchedAt: Date
  let holidays: [PublicHoliday]
}

private actor HolidayCache {
  private var cached: [Int: [PublicHoliday]] = [:]
  private let logger = Logger(subsystem: "com.promiso", category: "HolidayClient")

  // MARK: Disk Cache Helpers

  private func diskCacheURL(for year: Int) -> URL? {
    guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
      return nil
    }
    let dir = cachesDir.appendingPathComponent("holidays", isDirectory: true)
    return dir.appendingPathComponent("\(year).json")
  }

  private func loadFromDisk(for year: Int) -> [PublicHoliday]? {
    guard let url = diskCacheURL(for: year),
          let data = try? Data(contentsOf: url),
          let cached = try? JSONDecoder().decode(CachedHolidays.self, from: data)
    else { return nil }

    // 30일 이내 캐시만 유효 (임시공휴일 등 당해 변경 대응)
    let age = Date().timeIntervalSince(cached.fetchedAt)
    guard age < 30 * 24 * 60 * 60 else { return nil }

    return cached.holidays
  }

  private func saveToDisk(_ holidays: [PublicHoliday], for year: Int) {
    guard let url = diskCacheURL(for: year) else { return }

    let dir = url.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let wrapper = CachedHolidays(fetchedAt: Date(), holidays: holidays)
    guard let data = try? JSONEncoder().encode(wrapper) else { return }
    try? data.write(to: url, options: .atomic)
  }

  // MARK: Fetch

  func fetchHolidays(for year: Int) async throws -> [PublicHoliday] {
    // 메모리 캐시 HIT
    if let hit = cached[year] {
      return hit
    }

    // 디스크 캐시 HIT
    if let hit = loadFromDisk(for: year) {
      cached[year] = hit
      return hit
    }

    // ServiceKey 읽기 (Bundle Info.plist)
    guard let serviceKey = Bundle.main.object(forInfoDictionaryKey: "DATA_GO_KR_SERVICE_KEY") as? String,
          !serviceKey.isEmpty,
          serviceKey != "YOUR_DATA_GO_KR_SERVICE_KEY"
    else {
      logger.error("공휴일 API 서비스키 미설정")
      throw HolidayAPIError.serviceKeyNotFound
    }

    // URL 직접 조립 (ServiceKey가 이미 percent-encoded 상태 → URLQueryItem 이중 인코딩 방지)
    guard let url = URL(string: "https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo?solYear=\(year)&numOfRows=100&_type=json&ServiceKey=\(serviceKey)") else {
      throw HolidayAPIError.invalidURL
    }

    let (data, _) = try await URLSession.shared.data(from: url)

    let decoder = JSONDecoder()
    let response = try decoder.decode(DataGoKRResponse.self, from: data)

    // API 오류 코드 확인
    guard response.response.header.resultCode == "00" else {
      logger.error("공휴일 API 오류 [\(response.response.header.resultCode)]: \(response.response.header.resultMsg)")
      throw HolidayAPIError.apiError(
        code: response.response.header.resultCode,
        message: response.response.header.resultMsg
      )
    }

    let items = response.response.body?.items?.item ?? []

    guard let koreaTimeZone = TimeZone(identifier: "Asia/Seoul") else {
      struct TimeZoneError: Error, LocalizedError {
        var errorDescription: String? { "Could not initialize Asia/Seoul timezone." }
      }
      throw TimeZoneError()
    }
    var koreaCalendar = Calendar(identifier: .gregorian)
    koreaCalendar.timeZone = koreaTimeZone

    let holidays = items.compactMap { item -> PublicHoliday? in
      // locdate (Int: 20260505) → Date 변환
      let locdate = item.locdate
      let itemYear = locdate / 10000
      let month = (locdate % 10000) / 100
      let day = locdate % 100

      var components = DateComponents()
      components.year = itemYear
      components.month = month
      components.day = day

      guard let date = koreaCalendar.date(from: components) else { return nil }
      let normalized = koreaCalendar.startOfDay(for: date)

      return PublicHoliday(date: normalized, localName: item.dateName, name: item.dateName)
    }

    cached[year] = holidays
    saveToDisk(holidays, for: year)
    return holidays
  }
}

// MARK: - API Error

private enum HolidayAPIError: Error, LocalizedError {
  case serviceKeyNotFound
  case apiError(code: String, message: String)
  case invalidURL

  var errorDescription: String? {
    switch self {
    case .serviceKeyNotFound:
      return "공공데이터포털 서비스키가 설정되지 않았습니다."
    case .apiError(let code, let message):
      return "공공데이터포털 API 오류 [\(code)]: \(message)"
    case .invalidURL:
      return "잘못된 API URL입니다."
    }
  }
}

// MARK: - API Response Models
// 공공데이터포털 JSON 응답 구조:
// {
//   "response": {
//     "header": { "resultCode": "00", "resultMsg": "NORMAL SERVICE." },
//     "body": {
//       "items": {
//         "item": [
//           { "dateKind": "01", "dateName": "새해", "isHoliday": "Y", "locdate": 20260101, "seq": 1 }
//         ]
//       },
//       "numOfRows": 100, "pageNo": 1, "totalCount": 17
//     }
//   }
// }

private struct DataGoKRResponse: Decodable {
  let response: ResponseBody
}

private struct ResponseBody: Decodable {
  let header: ResponseHeader
  let body: ResponseBodyContent?
}

private struct ResponseHeader: Decodable {
  let resultCode: String
  let resultMsg: String
}

private struct ResponseBodyContent: Decodable {
  let items: ResponseItems?
  let totalCount: Int
}

private struct ResponseItems: Decodable {
  let item: [HolidayItem]

  // item이 단건일 때 객체, 복수일 때 배열로 오는 API 특성 대응
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let array = try? container.decode([HolidayItem].self, forKey: .item) {
      item = array
    } else if let single = try? container.decode(HolidayItem.self, forKey: .item) {
      item = [single]
    } else {
      item = []
    }
  }

  enum CodingKeys: String, CodingKey {
    case item
  }
}

private struct HolidayItem: Decodable {
  let dateName: String  // "어린이날", "대체공휴일(어린이날)" 등
  let locdate: Int      // 20260505 (YYYYMMDD 정수)
  let isHoliday: String // "Y" or "N"
}
