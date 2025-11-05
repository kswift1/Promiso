import Clients

struct PromiseCard: View {
  let promise: PromiseItem
  let onAccept: () -> Void
  let onReject: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack(alignment: .top, spacing: 12) {
        Text(promise.emoji)
          .font(.system(size: 40))

        VStack(alignment: .leading, spacing: 8) {
          Text(promise.title)
            .font(.system(size: 18, weight: .bold))

          // Time
          HStack(spacing: 6) {
            Image(systemName: "clock")
              .font(.system(size: 14))
            Text(promise.time)
              .font(.system(size: 14))
          }
          .foregroundColor(.secondary)

          // Location
          HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
              .font(.system(size: 14))
            Text(promise.location)
              .font(.system(size: 14))
            if let distance = promise.distance {
              Text("· \(distance)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
          }
          .foregroundColor(.secondary)

          // With
          HStack(spacing: 6) {
            Image(systemName: "person")
              .font(.system(size: 14))
            Text("with \(promise.with)")
              .font(.system(size: 14))
          }
          .foregroundColor(.secondary)
        }

        Spacer()
      }

      // Status & Responses
      HStack(spacing: 8) {
        StatusBadge(status: promise.status)

        if let responses = promise.responses {
          Text("\(responses.current)/\(responses.total)명 응답")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }

        Spacer()

        if let deadline = promise.deadline, promise.status == .needResponse {
          HStack(spacing: 4) {
            Image(systemName: "clock.fill")
              .font(.system(size: 12))
            Text(deadline)
              .font(.system(size: 12, weight: .medium))
          }
          .foregroundColor(.orange)
        }
      }

      // Action Buttons
      if promise.status == .needResponse {
        HStack(spacing: 8) {
          Button(action: onAccept) {
            Text("수락")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(Color.blue)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          Button(action: onReject) {
            Text("거절")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.primary)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(Color(.systemGray6))
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }
        }
      }
    }
    .padding(16)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color(.systemGray5), lineWidth: 1)
    )
  }
}

private struct StatusBadge: View {
  let status: PromiseStatus

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: status.iconName)
        .font(.system(size: 12, weight: .semibold))

      Text(status.displayText)
        .font(.system(size: 12, weight: .semibold))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(backgroundColor)
    .foregroundColor(foregroundColor)
    .clipShape(Capsule())
  }

  private var backgroundColor: Color {
    switch status {
    case .needResponse:
      return Color.orange.opacity(0.1)
    case .confirmed:
      return Color.green.opacity(0.1)
    case .sent:
      return Color.blue.opacity(0.1)
    }
  }

  private var foregroundColor: Color {
    switch status {
    case .needResponse:
      return Color.orange
    case .confirmed:
      return Color.green
    case .sent:
      return Color.blue
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 16) {
    PromiseCard(
      promise: PromiseItem(
        id: "1",
        title: "카페 데이트",
        emoji: "☕",
        time: "오후 2:00",
        date: "오늘",
        location: "스타벅스 강남점",
        distance: "1.2km",
        with: "지민",
        status: .needResponse,
        responses: PromiseResponse(current: 0, total: 2),
        deadline: "3시간 후"
      ),
      onAccept: {},
      onReject: {}
    )

    PromiseCard(
      promise: PromiseItem(
        id: "2",
        title: "저녁 식사",
        emoji: "🍽️",
        time: "오후 7:00",
        date: "오늘",
        location: "이탈리안 레스토랑",
        distance: "2.5km",
        with: "지민",
        status: .confirmed,
        responses: PromiseResponse(current: 2, total: 2),
        deadline: nil
      ),
      onAccept: {},
      onReject: {}
    )
  }
  .padding()
  .background(Color(.systemGray6))
}

extension PromiseStatus {
  var displayText: String {
    switch self {
    case .needResponse: return "답변 필요"
    case .confirmed: return "확정됨"
    case .sent: return "응답 대기"
    }
  }

  var color: String {
    switch self {
    case .needResponse: return "orange"
    case .confirmed: return "green"
    case .sent: return "blue"
    }
  }

  var iconName: String {
    switch self {
    case .needResponse: return "exclamationmark.circle.fill"
    case .confirmed: return "checkmark.circle.fill"
    case .sent: return "paperplane.fill"
    }
  }
}
