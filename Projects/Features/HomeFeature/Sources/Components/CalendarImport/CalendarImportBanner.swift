//
//  CalendarImportBanner.swift
//  HomeFeature
//
//  홈 상단 캘린더 임포트 배너

import SwiftUI
import PromisoShared

/// 캘린더 접근 권한이 없거나 스킵한 유저에게 표시하는 배너
struct CalendarImportBanner: View {
  let onTap: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "calendar.badge.plus")
        .font(.title3)
        .foregroundStyle(Color.pmsuccess.n500)

      VStack(alignment: .leading, spacing: 2) {
        Text("캘린더에서 일정 가져오기")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(Color.pmtext.primary)

        Text("Apple Calendar 일정을 한눈에 보세요")
          .font(.caption)
          .foregroundStyle(Color.pmtext.secondary)
      }

      Spacer()

      Button {
        onDismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.caption.weight(.medium))
          .foregroundStyle(Color.pmgray.n400)
          .padding(8)
      }
      .contentShape(Rectangle())
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .adaptiveGlassBackground(cornerRadius: 12)
    .contentShape(Rectangle())
    .onTapGesture {
      onTap()
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 16) {
    CalendarImportBanner(
      onTap: { },
      onDismiss: { }
    )

    Spacer()
  }
  .padding()
  .auroraBackground()
}
