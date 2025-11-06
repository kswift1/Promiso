import Clients
import Shared

struct PromiseCard: View {
  let promise: PromiseItem
  let onAccept: () -> Void
  let acceptLoading: Bool
  let onReject: () -> Void
  let rejectLoading: Bool
  
  var buttonDisabled: Bool {
    acceptLoading || rejectLoading
  }
  
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
      
      if promise.status == .needResponse {
        HStack(spacing: 12) {
          IndicatorButton.promiseAction(
            "수락",
            isLoading: acceptLoading,
            isDisabled: rejectLoading, // 거절 중이면 비활성화
            style: .primary,
            action: onAccept
          )
          
          IndicatorButton.promiseAction(
            "거절",
            isLoading: rejectLoading,
            isDisabled: acceptLoading, // 수락 중이면 비활성화
            style: .secondary,
            fallbackBackground: Color(.systemGroupedBackground),
            action: onReject
          )
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

// MARK: - Extension

extension PromiseStatus {
  var displayText: String {
    switch self {
    case .needResponse: return "답변 필요"
    case .confirmed: return "확정됨"
    case .sent: return "응답 대기"
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
