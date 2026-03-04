// MARK: - CalendarFilterModels.swift
// 캘린더 필터 관련 모델

import SwiftUI
import PromisoShared

// MARK: - CategoryFilterItem 채택

extension CalendarFeature.StatusFilter: CategoryFilterItem {
  public var title: String {
    switch self {
    case .all: return "전체"
    case .needResponse: return "응답필요"
    case .confirmed: return "확정"
    case .unconfirmed: return "미확정"
    }
  }

  public var icon: String {
    switch self {
    case .all: return "tray.fill"
    case .needResponse: return "envelope.badge"
    case .confirmed: return "checkmark.circle.fill"
    case .unconfirmed: return "clock.badge"
    }
  }

  public var selectedColor: Color {
    switch self {
    case .all: return .blue
    case .needResponse: return .orange
    case .confirmed: return .green
    case .unconfirmed: return Color.pmindigo.n400
    }
  }
}
