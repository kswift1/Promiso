import ComposableArchitecture
import Foundation

// MARK: - Client

/// OCR + TextParsing 통합 Client
/// 이미지 → OCR → 파싱, 텍스트 → 파싱
@DependencyClient
public struct PromiseExtractionClient: Sendable {
  /// 텍스트에서 약속 정보 추출
  public var extractFromText: @Sendable (_ text: String) async throws -> PromiseExtractedInfo

  /// 이미지에서 약속 정보 추출 (OCR + 파싱)
  public var extractFromImage: @Sendable (_ imageData: Data) async throws -> PromiseExtractedInfo
}

// MARK: - Test & Preview Values

extension PromiseExtractionClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    extractFromText: { text in
      PromiseExtractedInfo(
        title: "주말 모임",
        date: Date().addingTimeInterval(86400),
        location: "강남역",
        rawText: text,
        source: .text
      )
    },
    extractFromImage: { _ in
      try await Task.sleep(for: .seconds(1))
      return PromiseExtractedInfo(
        title: "팀 회식",
        date: Date().addingTimeInterval(172800),
        location: "홍대입구",
        rawText: "팀 회식\n다음주 금요일 저녁 7시\n홍대입구역 근처",
        source: .image
      )
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var promiseExtractionClient: PromiseExtractionClient {
    get { self[PromiseExtractionClient.self] }
    set { self[PromiseExtractionClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension PromiseExtractionClient: DependencyKey {
  public static let liveValue: PromiseExtractionClient = {
    @Dependency(\.ocrClient) var ocrClient
    @Dependency(\.textParsingClient) var textParsingClient

    return PromiseExtractionClient(
      extractFromText: { text in
        try await textParsingClient.parse(text)
      },
      extractFromImage: { imageData in
        // 1. OCR로 텍스트 추출
        let lines = try await ocrClient.recognizeText(imageData)
        let fullText = lines.joined(separator: "\n")

        // 2. 추출된 텍스트 파싱
        var result = try await textParsingClient.parse(fullText)
        result.source = .image
        return result
      }
    )
  }()
}
