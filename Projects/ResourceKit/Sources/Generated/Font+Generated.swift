//
//  Font+Generated.swift
//  Promiso Typography System
//
//  사용법: .font(.pm.body) 또는 .font(.pm.headline)
//  크기 조정: TypographySpec.swift에서 size 값 변경
//

import SwiftUI

// MARK: - Font Extension

public extension Font {
  /// Promiso Typography System
  /// 사용법: .font(.pm.body), .font(.pm.headline)
  static let pm = PMTypography.self
}

// MARK: - PMTypography

public enum PMTypography {
  // MARK: - Large Titles (34pt)

  public static var largeTitle: Font {
    .system(size: 34, weight: .bold)
  }

  public static var largeTitleSemibold: Font {
    .system(size: 34, weight: .semibold)
  }

  // MARK: - Title (26pt)

  public static var title: Font {
    .system(size: 26, weight: .bold)
  }

  public static var titleSemibold: Font {
    .system(size: 26, weight: .semibold)
  }

  public static var titleMedium: Font {
    .system(size: 26, weight: .medium)
  }

  // MARK: - Title2 (22pt)

  public static var title2: Font {
    .system(size: 22, weight: .bold)
  }

  public static var title2Semibold: Font {
    .system(size: 22, weight: .semibold)
  }

  public static var title2Medium: Font {
    .system(size: 22, weight: .medium)
  }

  // MARK: - Title3 (20pt)

  public static var title3: Font {
    .system(size: 20, weight: .bold)
  }

  public static var title3Semibold: Font {
    .system(size: 20, weight: .semibold)
  }

  public static var title3Medium: Font {
    .system(size: 20, weight: .medium)
  }

  // MARK: - Headline (17pt semibold)

  public static var headline: Font {
    .system(size: 17, weight: .semibold)
  }

  public static var headlineBold: Font {
    .system(size: 17, weight: .bold)
  }

  // MARK: - Body (17pt)

  public static var body: Font {
    .system(size: 17, weight: .regular)
  }

  public static var bodyMedium: Font {
    .system(size: 17, weight: .medium)
  }

  public static var bodySemibold: Font {
    .system(size: 17, weight: .semibold)
  }

  public static var bodyBold: Font {
    .system(size: 17, weight: .bold)
  }

  // MARK: - Callout (16pt)

  public static var callout: Font {
    .system(size: 16, weight: .regular)
  }

  public static var calloutMedium: Font {
    .system(size: 16, weight: .medium)
  }

  public static var calloutSemibold: Font {
    .system(size: 16, weight: .semibold)
  }

  // MARK: - Subheadline (15pt)

  public static var subheadline: Font {
    .system(size: 15, weight: .regular)
  }

  public static var subheadlineMedium: Font {
    .system(size: 15, weight: .medium)
  }

  public static var subheadlineSemibold: Font {
    .system(size: 15, weight: .semibold)
  }

  // MARK: - Footnote (14pt)

  public static var footnote: Font {
    .system(size: 14, weight: .regular)
  }

  public static var footnoteMedium: Font {
    .system(size: 14, weight: .medium)
  }

  public static var footnoteSemibold: Font {
    .system(size: 14, weight: .semibold)
  }

  // MARK: - Caption (13pt)

  public static var caption: Font {
    .system(size: 13, weight: .regular)
  }

  public static var captionMedium: Font {
    .system(size: 13, weight: .medium)
  }

  public static var captionSemibold: Font {
    .system(size: 13, weight: .semibold)
  }

  // MARK: - Caption2 (12pt)

  public static var caption2: Font {
    .system(size: 12, weight: .regular)
  }

  public static var caption2Medium: Font {
    .system(size: 12, weight: .medium)
  }

  public static var caption2Semibold: Font {
    .system(size: 12, weight: .semibold)
  }

  // MARK: - Micro (11pt)

  public static var micro: Font {
    .system(size: 11, weight: .regular)
  }

  public static var microMedium: Font {
    .system(size: 11, weight: .medium)
  }

  public static var microSemibold: Font {
    .system(size: 11, weight: .semibold)
  }

  // MARK: - Micro2 (10pt)

  public static var micro2: Font {
    .system(size: 10, weight: .regular)
  }

  public static var micro2Medium: Font {
    .system(size: 10, weight: .medium)
  }

  public static var micro2Semibold: Font {
    .system(size: 10, weight: .semibold)
  }
}
