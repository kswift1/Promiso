import SwiftUI
import Clients
import ComposableArchitecture

struct ArrivalSharingSection: View {
  let store: StoreOf<CreatePromise.Feature>

  private var selectedMinutes: Int? {
    store.promise.trackingStartMinutesBefore
  }

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: "실시간 위치 공유",
      isRequired: false
    ) {
      VStack(spacing: 8) {
        // 설명
        Text("약속 시간 전부터 참가자들의 도착 현황을 공유합니다")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, 4)

        // 옵션 그리드 (2x2)
        LazyVGrid(columns: [
          GridItem(.flexible(), spacing: 8),
          GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
          ForEach(ArrivalSharingOption.allCases, id: \.self) { option in
            ArrivalSharingChip(
              option: option,
              isSelected: selectedMinutes == option.minutes
            ) {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if selectedMinutes == option.minutes {
                  store.send(.view(.setTrackingStartMinutes(nil)))
                } else {
                  store.send(.view(.setTrackingStartMinutes(option.minutes)))
                }
              }
            }
          }
        }

        // 사용 안 함 버튼
        Button {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            store.send(.view(.setTrackingStartMinutes(nil)))
          }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: selectedMinutes == nil ? "checkmark.circle.fill" : "circle")
              .font(.system(size: 18))
              .foregroundColor(selectedMinutes == nil ? .blue : .secondary)

            Text("사용 안 함")
              .font(.system(size: 14))
              .foregroundColor(selectedMinutes == nil ? .primary : .secondary)

            Spacer()
          }
          .padding(12)
          .background(selectedMinutes == nil ? Color.blue.opacity(0.08) : Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
      }
    }
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

  var shortDescription: String {
    switch self {
    case .thirtyMin: return "짧은 약속"
    case .oneHour: return "추천"
    case .twoHours: return "여유있게"
    case .threeHours: return "먼 거리"
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

struct ArrivalSharingChip: View {
  let option: ArrivalSharingOption
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        Text(option.title)
          .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
          .foregroundColor(isSelected ? .blue : .primary)

        Text(option.shortDescription)
          .font(.system(size: 11))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(isSelected ? Color.blue.opacity(0.08) : Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
      )
    }
    .buttonStyle(.plain)
  }
}
