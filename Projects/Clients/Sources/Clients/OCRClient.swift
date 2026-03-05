import ComposableArchitecture
import Foundation
import PromisoShared
import UIKit
import Vision

// MARK: - Error

public enum OCRError: Error, Equatable, Sendable {
  case imageConversionFailed
  case recognitionFailed(String)
  case noTextFound

  public var localizedDescription: String {
    switch self {
    case .imageConversionFailed:
      return "이미지 변환에 실패했습니다. 다시 시도해 주세요."
    case .recognitionFailed(let message):
      return "텍스트 인식에 실패했습니다. \(message)"
    case .noTextFound:
      return "이미지에서 텍스트를 찾지 못했습니다."
    }
  }
}

// MARK: - Client

/// Vision Framework 기반 OCR Client
@DependencyClient
public struct OCRClient: Sendable {
  /// 이미지 Data에서 텍스트 추출
  /// - Parameter imageData: 이미지 Data (JPEG/PNG)
  /// - Returns: 추출된 텍스트 줄 배열
  public var recognizeText: @Sendable (_ imageData: Data) async throws -> [String]
}

// MARK: - Test & Preview Values

extension OCRClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    recognizeText: { _ in
      try await Task.sleep(for: .seconds(1))
      return [
        "이번 주 토요일 모임",
        "3월 1일 오후 3시",
        "강남역 2번 출구",
        "다 같이 점심 먹어요!",
      ]
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var ocrClient: OCRClient {
    get { self[OCRClient.self] }
    set { self[OCRClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension OCRClient: DependencyKey {
  public static let liveValue: OCRClient = {
    OCRClient(
      recognizeText: { imageData in
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage
        else {
          throw OCRError.imageConversionFailed
        }

        let texts = try await performOCR(on: cgImage)

        guard !texts.isEmpty else {
          throw OCRError.noTextFound
        }

        return texts
      }
    )
  }()
}

// MARK: - Vision Framework OCR

/// iOS 18+ RecognizeTextRequest 사용
private func performOCR(on cgImage: CGImage) async throws -> [String] {
  var request = RecognizeTextRequest()
  request.recognitionLevel = .accurate
  request.recognitionLanguages = [
    Locale.Language(identifier: "ko-KR"),
    Locale.Language(identifier: "en-US"),
  ]
  request.usesLanguageCorrection = true

  let observations = try await request.perform(on: cgImage)

  return observations
    .compactMap { observation in
      guard let candidate = observation.topCandidates(1).first,
            candidate.confidence > 0.5
      else { return nil }
      return candidate.string
    }
}
