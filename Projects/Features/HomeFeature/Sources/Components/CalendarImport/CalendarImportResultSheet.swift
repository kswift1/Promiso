//
//  CalendarImportResultSheet.swift
//  HomeFeature
//
//  캘린더 임포트 결과 바텀시트

import SwiftUI
import PromisoShared

/// 온보딩 캘린더 임포트 완료 후 결과를 보여주는 바텀시트
struct CalendarImportResultSheet: View {
  let result: CalendarImportResult
  let onDismiss: () -> Void

  private var emoji: String {
    if result.totalImported > 0 {
      return "🎉"
    } else {
      return "📅"
    }
  }

  private var title: String {
    if result.thisWeekCount > 0 {
      return "이번 주 약속 \(result.thisWeekCount)개 가져왔어요"
    } else if result.totalImported > 0 {
      return "일정 가져왔어요"
    } else {
      return "아직 일정이 없네요"
    }
  }

  private var subtitle: String {
    if result.thisWeekCount > 0 {
      return "총 \(result.totalImported)개의 일정을 가져왔어요.\n다가오는 약속을 미리 챙겨드릴게요."
    } else if result.totalImported > 0 {
      return "총 \(result.totalImported)개의 일정을 가져왔어요.\n약속이 다가오면 미리 알려드릴게요."
    } else {
      return "첫 약속을 만들면 바로 챙겨드릴게요."
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      // 이모지
      Text(emoji)
        .font(.system(size: 48))
        .padding(.top, 24)

      // 타이틀
      VStack(spacing: 8) {
        Text(title)
          .font(.title3.bold())
          .foregroundStyle(Color.pmtext.primary)

        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(Color.pmtext.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
      }

      Spacer()

      // 확인 버튼
      Button {
        onDismiss()
      } label: {
        Text("확인")
          .font(.body.weight(.semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(Color.pmsuccess.n500, in: RoundedRectangle(cornerRadius: 14))
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 16)
    }
  }
}

// MARK: - Preview

#Preview("With This Week Schedule") {
  CalendarImportResultSheet(
    result: CalendarImportResult(totalImported: 5, thisWeekCount: 2),
    onDismiss: { }
  )
}

#Preview("With Total Schedule") {
  CalendarImportResultSheet(
    result: CalendarImportResult(totalImported: 10, thisWeekCount: 0),
    onDismiss: { }
  )
}

#Preview("Empty") {
  CalendarImportResultSheet(
    result: CalendarImportResult(totalImported: 0, thisWeekCount: 0),
    onDismiss: { }
  )
}
