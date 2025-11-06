import SwiftUI
import Clients
import ComposableArchitecture

struct ArrivalSharingSection: View {
  let store: StoreOf<CreatePromise.Feature>

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: "도착 상황 공유 시작",
      isRequired: false
    ) {
      content
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 16) {
      descriptionSection
      optionsSection
      if store.promiseProposal.arrivalSharingTime != nil {
        additionalInfoSection
      }
    }
  }

  private var descriptionSection: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "location.fill.viewfinder")
        .font(.system(size: 20))
        .foregroundColor(.blue)

      VStack(alignment: .leading, spacing: 4) {
        Text("약속 시간 전부터 멤버들이 서로의 도착 예정 시간을 볼 수 있습니다")
          .font(.system(size: 14))
          .foregroundColor(.primary)
          .fixedSize(horizontal: false, vertical: true)

        Text("라이브 액티비티로 실시간 도착 현황을 확인할 수 있어요")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(16)
    .background(Color.blue.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var optionsSection: some View {
    VStack(spacing: 12) {
      ForEach(ArrivalSharingOption.allCases, id: \.self) { option in
        let isSelected = store.promiseProposal.arrivalSharingTime == option.minutes
        let currentValue = store.promiseProposal.arrivalSharingTime

        ArrivalSharingButton(
          option: option,
          isSelected: isSelected,
          action: {
            let newValue = currentValue == option.minutes ? nil : option.minutes
            store.send(
              .view(.setArrivalSharingTime(newValue)),
              animation: .spring(response: 0.3, dampingFraction: 0.7)
            )
          }
        )
      }
    }
  }

  private var additionalInfoSection: some View {
    HStack(spacing: 8) {
      Image(systemName: "info.circle.fill")
        .font(.system(size: 12))
        .foregroundColor(.green)

      VStack(alignment: .leading, spacing: 2) {
        Text("설정한 시간부터 라이브 액티비티가 시작됩니다")
          .font(.system(size: 13))
          .foregroundColor(.primary)

        Text("멤버들의 출발 여부와 도착 예정 시간을 실시간으로 확인할 수 있어요")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }

      Spacer(minLength: 0)
    }
    .padding(12)
    .background(Color.green.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

// MARK: - Arrival Sharing Option
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

// MARK: - Arrival Sharing Button
struct ArrivalSharingButton: View {
  let option: ArrivalSharingOption
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        // 아이콘
        ZStack {
          Circle()
            .fill(isSelected ? Color.blue : Color(.systemGray5))
            .frame(width: 40, height: 40)

          Image(systemName: option.icon)
            .font(.system(size: 18))
            .foregroundColor(isSelected ? .white : .secondary)
        }

        // 텍스트
        VStack(alignment: .leading, spacing: 2) {
          Text(option.title)
            .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
            .foregroundColor(.primary)

          Text(option.description)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }

        Spacer()

        // 체크마크
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

// MARK: - Preview
#Preview("선택 안됨") {
  ScrollView {
    ArrivalSharingSection(
      store: Store(
        initialState: CreatePromise.Feature.State(
          promiseProposal: PromiseProposal(
            title: "저녁 식사",
            emoji: "🍽️",
            group: .init(
              id: "g1",
              emoji: "👥",
              title: "친구들",
              memberCount: 4
            ),
            startedAt: Date().addingTimeInterval(7200),
            minimumParticipants: 2,
            arrivalSharingTime: nil
          )
        )
      ) {
        CreatePromise.Feature()
      }
    )
    .padding()
  }
}

#Preview("1시간 전 선택됨") {
  ScrollView {
    ArrivalSharingSection(
      store: Store(
        initialState: CreatePromise.Feature.State(
          promiseProposal: PromiseProposal(
            title: "저녁 식사",
            emoji: "🍽️",
            group: .init(
              id: "g1",
              emoji: "👥",
              title: "친구들",
              memberCount: 4
            ),
            startedAt: Date().addingTimeInterval(7200),
            minimumParticipants: 2,
            arrivalSharingTime: 60
          )
        )
      ) {
        CreatePromise.Feature()
      }
    )
    .padding()
  }
}

#Preview("다크모드") {
  ScrollView {
    ArrivalSharingSection(
      store: Store(
        initialState: CreatePromise.Feature.State(
          promiseProposal: PromiseProposal(
            title: "주말 등산",
            emoji: "⛰️",
            group: .init(
              id: "g2",
              emoji: "🥾",
              title: "등산 모임",
              memberCount: 6
            ),
            startedAt: Date().addingTimeInterval(10800),
            minimumParticipants: 4,
            arrivalSharingTime: 120
          )
        )
      ) {
        CreatePromise.Feature()
      }
    )
    .padding()
  }
  .preferredColorScheme(.dark)
}
