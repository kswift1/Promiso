import ComposableArchitecture
import Foundation
import NaturalLanguage

// MARK: - Client

/// 텍스트에서 약속 정보를 추출하는 Client
/// KoreanDateParser + NLTagger(장소명 NER) + 제목 추론 조합
@DependencyClient
public struct TextParsingClient: Sendable {
  /// 텍스트에서 약속 정보 추출
  /// - Parameter text: 입력 텍스트
  /// - Returns: 추출된 약속 정보
  public var parse: @Sendable (_ text: String) async throws -> PromiseExtractedInfo
}

// MARK: - Test & Preview Values

extension TextParsingClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    parse: { text in
      PromiseExtractedInfo(
        title: "주말 모임",
        date: Date().addingTimeInterval(86400),
        location: "강남역",
        description: nil,
        rawText: text,
        source: .text
      )
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var textParsingClient: TextParsingClient {
    get { self[TextParsingClient.self] }
    set { self[TextParsingClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension TextParsingClient: DependencyKey {
  public static let liveValue: TextParsingClient = {
    TextParsingClient(
      parse: { text in
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
          return PromiseExtractedInfo(rawText: text, source: .text)
        }

        let date = KoreanDateParser.parse(trimmed)
        let location = extractLocation(from: trimmed)
        let title = extractTitle(from: trimmed)

        return PromiseExtractedInfo(
          title: title,
          date: date,
          location: location,
          description: nil,
          rawText: text,
          source: .text
        )
      }
    )
  }()
}

// MARK: - Location Extraction (NLTagger NER)

private func extractLocation(from text: String) -> String? {
  let tagger = NLTagger(tagSchemes: [.nameType])
  tagger.string = text

  var places: [String] = []
  let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

  tagger.enumerateTags(
    in: text.startIndex..<text.endIndex,
    unit: .word,
    scheme: .nameType,
    options: options
  ) { tag, range in
    if tag == .placeName {
      places.append(String(text[range]))
    }
    return true
  }

  // NLTagger 결과가 없으면 키워드 기반 폴백
  if places.isEmpty {
    return extractLocationByKeyword(from: text)
  }

  return places.first
}

/// 키워드 기반 장소 추출 폴백
/// "~에서", "~앞", "~역" 등의 패턴으로 장소 추출
private func extractLocationByKeyword(from text: String) -> String? {
  // "OO에서", "OO 앞에서" 패턴
  let locationPatterns: [String] = [
    #"(\S{2,15})\s*에서"#,
    #"(\S{2,15}(?:역|카페|공원|식당|건물|센터|몰|백화점|마트|학교|대학교|병원|호텔|극장|영화관))"#,
    #"장소[:\s]+(.+?)(?:\n|$)"#,
  ]

  for pattern in locationPatterns {
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let range = Range(match.range(at: 1), in: text)
    else { continue }

    let location = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    if !location.isEmpty && location.count <= 30 {
      return location
    }
  }

  return nil
}

// MARK: - Title Extraction

/// 텍스트에서 제목 추론
/// 전략: 첫 줄 또는 가장 짧은 의미있는 줄
private func extractTitle(from text: String) -> String? {
  let lines = text.components(separatedBy: .newlines)
    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    .filter { !$0.isEmpty }

  guard !lines.isEmpty else { return nil }

  // 날짜/시간/장소 키워드가 아닌 첫 번째 줄을 제목으로
  let dateKeywords = ["오전", "오후", "시", "분", "월", "일", "요일", "내일", "모레", "다음주"]
  let locationKeywords = ["에서", "역", "앞", "장소"]

  for line in lines {
    let isDateLine = dateKeywords.contains(where: { line.contains($0) })
    let isLocationLine = locationKeywords.contains(where: { line.contains($0) })

    // 날짜/장소가 아닌 짧은 줄 = 제목
    if !isDateLine && !isLocationLine && line.count <= 30 {
      return line
    }
  }

  // 모든 줄이 날짜/장소면 첫 줄에서 30자 잘라서 사용
  let firstLine = lines[0]
  if firstLine.count > 30 {
    return String(firstLine.prefix(30))
  }
  return firstLine
}
