import Foundation

/// Gemini API 응답 DTO
public struct GeminiResponse: Decodable, Sendable {
  public let candidates: [Candidate]?
  public let error: GeminiError?

  public struct Candidate: Decodable, Sendable {
    public let content: Content?
    public let finishReason: String?
  }

  public struct Content: Decodable, Sendable {
    public let parts: [Part]?
    public let role: String?
  }

  public struct Part: Decodable, Sendable {
    public let text: String?
  }

  public struct GeminiError: Decodable, Sendable {
    public let code: Int?
    public let message: String?
    public let status: String?
  }

  /// 응답에서 텍스트 추출
  public var text: String? {
    candidates?.first?.content?.parts?.first?.text
  }
}
