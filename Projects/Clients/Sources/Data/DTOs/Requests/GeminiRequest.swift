import Foundation

/// Gemini API 요청 DTO
public struct GeminiRequest: Encodable, Sendable {
  public let contents: [Content]
  public let generationConfig: GenerationConfig

  public init(prompt: String, temperature: Double = 0.1, maxOutputTokens: Int = 10) {
    self.contents = [
      Content(parts: [Part(text: prompt)])
    ]
    self.generationConfig = GenerationConfig(
      temperature: temperature,
      maxOutputTokens: maxOutputTokens
    )
  }

  public struct Content: Encodable, Sendable {
    public let parts: [Part]
  }

  public struct Part: Encodable, Sendable {
    public let text: String
  }

  public struct GenerationConfig: Encodable, Sendable {
    public let temperature: Double
    public let maxOutputTokens: Int
  }
}
