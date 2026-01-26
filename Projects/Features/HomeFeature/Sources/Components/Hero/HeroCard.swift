import SwiftUI
import PromisoShared

/// 홈 상단 Hero 영역 - "지금 가장 중요한 약속 1개"
struct HeroCard: View {
  let data: HeroData
  let onTap: () -> Void
  let onActionTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 16) {
        // Header: 우선순위 배지 + 시간
        HStack {
          priorityBadge
          Spacer()
          timeUntilText
        }

        // Promise Info
        HStack(spacing: 14) {
          Text(data.promise.displayEmoji)
            .font(.system(size: 44))

          VStack(alignment: .leading, spacing: 8) {
            Text(data.promise.title)
              .font(.title2)
              .fontWeight(.bold)
              .lineLimit(2)
              .foregroundStyle(.primary)

            if let location = data.promise.location {
              HStack(spacing: 4) {
                Image(systemName: "location.fill")
                  .font(.caption)
                Text(location.name)
                  .font(.subheadline)
                  .lineLimit(1)
              }
              .foregroundStyle(.secondary)
            }

            // 시작 시간
            HStack(spacing: 4) {
              Image(systemName: "clock")
                .font(.caption)
              Text(startTimeText)
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .foregroundStyle(priorityColor)
          }
        }

        // CTA Button
        Button(action: onActionTap) {
          HStack {
            Image(systemName: ctaIcon)
            Text(ctaText)
          }
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(priorityColor)
          .cornerRadius(12)
        }
        .buttonStyle(.plain)
      }
      .padding(20)
      .background(heroBackground)
      .cornerRadius(24)
      .shadow(color: priorityColor.opacity(0.25), radius: 20, x: 0, y: 10)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Subviews

  @ViewBuilder
  private var priorityBadge: some View {
    HStack(spacing: 6) {
      Image(systemName: data.priority.iconName)
        .font(.caption)
      Text(data.priority.displayTitle)
        .font(.caption)
        .fontWeight(.semibold)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(priorityColor)
    .cornerRadius(8)
  }

  @ViewBuilder
  private var timeUntilText: some View {
    Text(relativeTimeText)
      .font(.subheadline)
      .fontWeight(.medium)
      .foregroundStyle(priorityColor)
  }

  // MARK: - Computed Properties

  private var priorityColor: Color {
    switch data.priority {
    case .departureSoon: return .orange
    case .todayNext: return Color.pmindigo.n500
    case .needResponse: return Color.pmaurora.purple
    }
  }

  private var heroBackground: some ShapeStyle {
    LinearGradient(
      colors: [priorityColor.opacity(0.12), priorityColor.opacity(0.04)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var relativeTimeText: String {
    let now = Date()
    let interval = data.promise.startAt.timeIntervalSince(now)

    if interval < 0 {
      return "진행 중"
    }

    let minutes = Int(interval / 60)
    if minutes < 60 {
      return "\(minutes)분 후"
    }

    let hours = minutes / 60
    if hours < 24 {
      return "\(hours)시간 후"
    }

    let days = hours / 24
    return "\(days)일 후"
  }

  private var startTimeText: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M월 d일 (E) HH:mm"
    formatter.locale = Locale(identifier: "ko_KR")
    return formatter.string(from: data.promise.startAt)
  }

  private var ctaIcon: String {
    switch data.priority {
    case .departureSoon: return "location.fill"
    case .todayNext: return "arrow.right.circle.fill"
    case .needResponse: return "hand.raised.fill"
    }
  }

  private var ctaText: String {
    switch data.priority {
    case .departureSoon: return "길찾기 시작"
    case .todayNext: return "상세 보기"
    case .needResponse: return "지금 응답하기"
    }
  }
}

// MARK: - Preview

// Preview는 PromiseModel.mock이 필요하므로 Example 타겟에서 테스트
