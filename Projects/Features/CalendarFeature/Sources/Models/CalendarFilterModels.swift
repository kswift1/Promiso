// MARK: - CalendarFilterModels.swift
// 캘린더 필터 관련 모델

import SwiftUI
import PromisoShared

// MARK: - CategoryFilterItem 채택

extension CalendarFeature.StatusFilter: CategoryFilterItem {
  public var title: String {
    switch self {
    case .all: return LocalizedStrings.Common.all
    case .needResponse: return LocalizedStrings.ScheduleCard.statusNeedResponse
    case .waitingConfirmation: return LocalizedStrings.Shared.statusWaitingConfirm
    case .confirmed: return LocalizedStrings.Calendar.statusConfirmed
    case .completed: return LocalizedStrings.Schedule.completed
    case .failed: return LocalizedStrings.Calendar.statusFailed
    }
  }

  public var icon: String {
    switch self {
    case .all: return "tray.fill"
    case .needResponse: return "envelope.badge"
    case .waitingConfirmation: return "clock.badge"
    case .confirmed: return "checkmark.circle.fill"
    case .completed: return "checkmark.seal.fill"
    case .failed: return "xmark.circle.fill"
    }
  }

  public var selectedColor: Color {
    switch self {
    case .all: return Color.pmindigo.n500
    case .needResponse: return Color.pmwarning.n500
    case .waitingConfirmation: return Color.pminfo.n500
    case .confirmed: return Color.pmsuccess.n500
    case .completed: return Color.pmgray.n500
    case .failed: return Color.pmerror.n500
    }
  }
}
