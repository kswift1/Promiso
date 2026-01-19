import SwiftUI
import Clients
import ComposableArchitecture

struct ArrivalSharingSection: View {
  let store: StoreOf<CreatePromise.Feature>

  private var selectedOption: ArrivalSharingOption? {
    guard let minutes = store.promise.trackingStartMinutesBefore else {
      return nil
    }
    return ArrivalSharingOption.allCases.first { $0.minutes == minutes }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // 헤더
      HStack(spacing: 8) {
        Image(systemName: "location.fill.viewfinder")
          .font(.system(size: 20))
          .foregroundColor(.blue)

        Text("실시간 위치 공유")
          .font(.system(size: 18, weight: .semibold))
      }

      Text("약속 시간 전부터 참가자들의 위치를 실시간으로 공유합니다")
        .font(.system(size: 14))
        .foregroundColor(.secondary)

      // 옵션 버튼들
      VStack(spacing: 12) {
        ForEach(ArrivalSharingOption.allCases, id: \.self) { option in
          ArrivalSharingButton(
            option: option,
            isSelected: selectedOption == option
          ) {
            if selectedOption == option {
              // 이미 선택된 것을 다시 누르면 해제
              store.send(.view(.setTrackingStartMinutes(nil)))
            } else {
              store.send(.view(.setTrackingStartMinutes(option.minutes)))
            }
          }
        }
      }

      // 비활성화 옵션
      Button {
        store.send(.view(.setTrackingStartMinutes(nil)))
      } label: {
        HStack {
          Image(systemName: "xmark.circle")
            .font(.system(size: 18))
          Text("위치 공유 안 함")
            .font(.system(size: 15))
          Spacer()
          if selectedOption == nil {
            Image(systemName: "checkmark")
              .foregroundColor(.blue)
          }
        }
        .foregroundColor(selectedOption == nil ? .blue : .secondary)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
          selectedOption == nil
            ? Color.blue.opacity(0.08)
            : Color(.systemGray6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(PlainButtonStyle())
    }
    .padding(16)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
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
