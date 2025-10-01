// EmojiLoader.swift
import Foundation

#if SWIFT_PACKAGE
private let resourceBundle: Bundle = .module
#else
private final class _BundleToken {}
private let resourceBundle: Bundle = {
  // Shared 프레임워크의 리소스 번들 탐색
  let codeBundle = Bundle(for: _BundleToken.self)

  // 1. Shared_Shared.bundle 형태 확인 (Tuist 기본 패턴)
  if let url = codeBundle.url(forResource: "Shared_Shared", withExtension: "bundle"),
     let res = Bundle(url: url) {
    return res
  }

  // 2. Shared.bundle 형태 확인
  if let url = codeBundle.url(forResource: "Shared", withExtension: "bundle"),
     let res = Bundle(url: url) {
    return res
  }

  // 3. 직접 코드 번들에서 찾기
  return codeBundle
}()
#endif

public enum EmojiLoader {
  public static func loadCompact(from subdirectory: String? = nil,
                                 filename: String = "emoji_compact.raw") throws -> [EmojiEntry] {
    // 여러 경로 시도
    let possibleURLs: [URL?] = [
      // 1. subdirectory가 있는 경우
      subdirectory.flatMap { resourceBundle.url(forResource: filename, withExtension: "json", subdirectory: $0) },
      // 2. 루트에서 찾기
      resourceBundle.url(forResource: filename, withExtension: "json"),
      // 3. Resources 폴더에서 찾기
      resourceBundle.url(forResource: filename, withExtension: "json", subdirectory: "Resources")
    ]

    guard let url = possibleURLs.compactMap({ $0 }).first else {
      print("❌ Failed to find \(filename).json")
      print("   Bundle: \(resourceBundle.bundlePath)")
      print("   Subdirectory: \(subdirectory ?? "nil")")
      throw NSError(domain: "EmojiLoader", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "\(filename).json not found"])
    }

    print("✅ Found emoji file at: \(url.path)")
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([EmojiEntry].self, from: data)
  }
}
