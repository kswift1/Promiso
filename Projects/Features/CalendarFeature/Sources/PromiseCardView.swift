// MARK: - PromiseCardView.swift
// 약속 카드 뷰 컴포넌트

import SwiftUI

// MARK: - Promise Card View

/// 약속 카드 (하단 리스트용)
struct PromiseCardView: View {
  let promise: MockPromise
  let onTap: () -> Void
  let onRespond: (() -> Void)?

  init(
    promise: MockPromise,
    onTap: @escaping () -> Void,
    onRespond: (() -> Void)? = nil
  ) {
    self.promise = promise
    self.onTap = onTap
    self.onRespond = onRespond
  }

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 12) {
        // 상단: 상태 + 시간
        HStack(spacing: 8) {
          // 상태 아이콘
          Image(systemName: promise.status.icon)
            .font(.system(size: 14))
            .foregroundColor(promise.status.color)

          // 시간
          Text(promise.timeText)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)

          Spacer()

          // 위치 (있는 경우)
          if let location = promise.location {
            HStack(spacing: 4) {
              Image(systemName: "location.fill")
                .font(.system(size: 10))
              Text(location)
                .font(.system(size: 12))
                .lineLimit(1)
            }
            .foregroundColor(.secondary.opacity(0.8))
            .frame(maxWidth: 120, alignment: .trailing)
          }
        }

        // 제목 행
        HStack(spacing: 8) {
          Text(promise.emoji)
            .font(.system(size: 20))

          Text(promise.title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.primary)
            .lineLimit(1)
        }

        // 하단: 참여자 + 상태 텍스트
        HStack {
          // 참여자 요약
          if !promise.participantsSummary.isEmpty {
            HStack(spacing: 4) {
              Image(systemName: "person.2.fill")
                .font(.system(size: 11))
              Text(promise.participantsSummary)
                .font(.system(size: 13))
            }
            .foregroundColor(.secondary)
          }

          Spacer()

          // 상태 상세 텍스트
          Text(promise.statusDetailText)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(promise.status.color)
        }

        // 응답하기 버튼 (필요한 경우)
        if promise.needsMyResponse, let onRespond = onRespond {
          respondButton(action: onRespond)
        }
      }
      .padding(16)
      .background(cardBackground)
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(borderColor, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Subviews

  @ViewBuilder
  private func respondButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: "hand.tap.fill")
          .font(.system(size: 12))
        Text("응답하기")
          .font(.system(size: 14, weight: .semibold))
      }
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(Color.blue)
      .cornerRadius(10)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Computed Properties

  private var cardBackground: Color {
    switch promise.status {
    case .proposed:
      return Color.yellow.opacity(0.08)
    case .pending:
      return Color.orange.opacity(0.06)
    case .confirmed:
      return Color(.secondarySystemBackground)
    case .rejected:
      return Color(.systemGray6)
    }
  }

  private var borderColor: Color {
    switch promise.status {
    case .proposed:
      return Color.yellow.opacity(0.3)
    case .pending:
      return Color.orange.opacity(0.2)
    case .confirmed:
      return Color(.separator).opacity(0.3)
    case .rejected:
      return Color(.separator).opacity(0.2)
    }
  }
}

// MARK: - Promise List Section Header

/// 날짜별 섹션 헤더
struct PromiseListSectionHeader: View {
  let date: Date
  let isSelected: Bool

  private let calendar = Calendar.current

  var body: some View {
    HStack(spacing: 10) {
      // 요일
      Text(dayOfWeek)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(isSelected ? .blue : .secondary)

      // 날짜
      Text(formattedDate)
        .font(.system(size: 20, weight: .bold))
        .foregroundColor(isSelected ? .blue : .primary)

      // 오늘 뱃지
      if calendar.isDateInToday(date) {
        Text("오늘")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Color.blue)
          .cornerRadius(8)
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.ultraThinMaterial)
  }

  // MARK: - Computed Properties

  private var dayOfWeek: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "EEEE"
    return formatter.string(from: date)
  }

  private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter.string(from: date)
  }
}

// MARK: - Empty Day Placeholder

/// 약속이 없는 날 표시
struct EmptyDayPlaceholder: View {
  let date: Date

  var body: some View {
    HStack {
      Text("약속이 없습니다")
        .font(.system(size: 15))
        .foregroundColor(.secondary)
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 20)
  }
}

// MARK: - Preview

#Preview("Promise Card - Confirmed") {
  let promise = MockPromise(
    title: "점심 약속",
    emoji: "🍽️",
    date: Date(),
    startTime: Date(),
    location: "강남역 맛집",
    status: .confirmed,
    participants: [
      MockParticipant(name: "민수"),
      MockParticipant(name: "지영"),
      MockParticipant(name: "현우")
    ],
    totalParticipants: 4,
    acceptedCount: 4
  )

  PromiseCardView(promise: promise, onTap: {})
    .padding()
}

#Preview("Promise Card - Needs Response") {
  let promise = MockPromise(
    title: "카페 데이트",
    emoji: "☕",
    date: Date(),
    startTime: Date(),
    location: "스타벅스",
    status: .proposed,
    participants: [MockParticipant(name: "지영")],
    totalParticipants: 2,
    acceptedCount: 1,
    deadlineText: "내일 오전",
    needsMyResponse: true
  )

  PromiseCardView(promise: promise, onTap: {}, onRespond: {})
    .padding()
}

#Preview("Promise Card - Pending") {
  let promise = MockPromise(
    title: "저녁 회식",
    emoji: "🍻",
    date: Date(),
    startTime: Date(),
    location: "홍대 술집",
    status: .pending,
    participants: [
      MockParticipant(name: "민수"),
      MockParticipant(name: "지영")
    ],
    totalParticipants: 4,
    acceptedCount: 2,
    deadlineText: "3시간"
  )

  PromiseCardView(promise: promise, onTap: {})
    .padding()
}
