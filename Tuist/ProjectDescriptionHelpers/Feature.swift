// Tuist/ProjectDescriptionHelpers/Features.swift
import ProjectDescription

/// 확장 가능한 Feature 식별자 (enum 대신 struct로 설계: 케이스를 확장 파일로 자동 추가 가능)
public struct Feature: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  public let rawValue: String
  public init(_ rawValue: String) { self.rawValue = rawValue }
  public init(rawValue: String) { self.rawValue = rawValue }
  public var description: String { rawValue }
}

/// 공통 경로/이름 규칙
public enum FeaturePath {
  /// 기본 Features 폴더 상대 경로
  public static let root = "../Features"
  
  /// 특정 Feature의 폴더 경로
  public static func path(for feature: Feature, root: String = root) -> String {
    "\(root)/\(feature.rawValue)"
  }
  
  /// 타겟 이름들
  public static func interfaceName(_ feature: Feature) -> String { "\(feature.rawValue)FeatureInterface" }
  public static func implementName(_ feature: Feature) -> String { "\(feature.rawValue)FeatureImplement" }
  public static func testingName(_ feature: Feature) -> String { "\(feature.rawValue)FeatureTesting" }
  public static func testsName(_ feature: Feature) -> String { "\(feature.rawValue)FeatureTests" }
  public static func exampleName(_ feature: Feature) -> String { "\(feature.rawValue)FeatureExample" }
}
