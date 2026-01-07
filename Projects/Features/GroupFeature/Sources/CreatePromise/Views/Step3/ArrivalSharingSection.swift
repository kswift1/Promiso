import SwiftUI
import Clients
import ComposableArchitecture

// NOTE: Phase 2 기능 - 현재 비활성화
// arrivalSharingTime 필드가 PromiseModel에서 제거됨
// Phase 2에서 다시 활성화할 때 구현 필요
struct ArrivalSharingSection: View {
  let store: StoreOf<CreatePromise.Feature>

  var body: some View {
    // Phase 2에서 활성화 예정
    EmptyView()
  }
}

// MARK: - Phase 2에서 사용할 타입들

enum ArrivalSharingOption: CaseIterable, Hashable {
  case thirtyMin, oneHour, twoHours, threeHours

  var title: String {
    switch self {
    case .thirtyMin: return "30분 전부터"
    case .oneHour: return "1시간 전부터"
    case .twoHours: return "2시간 전부터"
    case .threeHours: return "3시간 전부터"
    }
  }

  var description: String {
    switch self {
    case .thirtyMin: return "짧은 약속에 적합"
    case .oneHour: return "일반적인 약속 (추천)"
    case .twoHours: return "여유있게 확인"
    case .threeHours: return "먼 거리 이동 시"
    }
  }

  var minutes: Int {
    switch self {
    case .thirtyMin: return 30
    case .oneHour: return 60
    case .twoHours: return 120
    case .threeHours: return 180
    }
  }

  var icon: String {
    switch self {
    case .thirtyMin: return "hare.fill"
    case .oneHour: return "checkmark.circle.fill"
    case .twoHours: return "clock.fill"
    case .threeHours: return "map.fill"
    }
  }
}

struct ArrivalSharingButton: View {
  let option: ArrivalSharingOption
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(isSelected ? Color.blue : Color(.systemGray5))
            .frame(width: 40, height: 40)

          Image(systemName: option.icon)
            .font(.system(size: 18))
            .foregroundColor(isSelected ? .white : .secondary)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(option.title)
            .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
            .foregroundColor(.primary)

          Text(option.description)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(.blue)
        } else {
          Image(systemName: "circle")
            .font(.system(size: 24))
            .foregroundColor(.secondary)
        }
      }
      .padding(16)
      .background(isSelected ? Color.blue.opacity(0.08) : Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}
