import SwiftUI
import Clients
import ComposableArchitecture

struct MinimumParticipantsSection: View {
  let store: StoreOf<CreatePromise.Feature>
  var scrollProxy: ScrollViewProxy? = nil
  
  // 현재 최소 참가 인원 (안전한 접근)
  private var currentMinimum: Int {
    store.promiseProposal.minimumParticipants ?? defaultMinimum
  }
  
  // 기본값: 최대 인원의 절반 (반올림)
  private var defaultMinimum: Int {
    guard let maxParticipants = store.promiseProposal.group?.memberCount else { return 2 }
    return Int(ceil(Double(maxParticipants) / 2.0))
  }
  
  // 2명 고정 여부
  private var isFixedAtTwo: Bool {
    store.promiseProposal.group?.memberCount == 2
  }
  
  // 최대 인원 (기본값 2명)
  private var maxParticipants: Int {
    store.promiseProposal.group?.memberCount ?? 2
  }
  
  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: "최소 참가 인원",
      isRequired: true
    ) {
      VStack(alignment: .leading, spacing: 12) {
        if isFixedAtTwo {
          // 2명 고정 케이스
          fixedParticipantsView
        } else {
          // 선택 가능한 케이스
          adjustableParticipantsView
          
          // 안내 박스
          infoBox
          
          // 경고 메시지 (최대 인원과 같을 때)
          if currentMinimum == maxParticipants {
            warningMessage
          }
        }
      }
    }
  }
  
  // MARK: - 2명 고정 UI
  private var fixedParticipantsView: some View {
    VStack(spacing: 16) {
      VStack(spacing: 8) {
        Text("2명")
          .font(.system(size: 36, weight: .bold))
          .foregroundColor(.primary)
        
        Text("최대 2명")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      
      // 고정 안내
      HStack(spacing: 12) {
        Image(systemName: "lock.fill")
          .font(.system(size: 16))
          .foregroundColor(.secondary)
        
        Text("그룹이 2명이므로 최소 참가 인원이 2명으로 고정됩니다")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
      .padding(16)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }
  
  // MARK: - 조정 가능한 UI
  private var adjustableParticipantsView: some View {
    HStack(spacing: 16) {
      Button(
        action: {
          store.send(
            .view(.decrementParticipants),
            animation: .spring(response: 0.3, dampingFraction: 0.7)
          )
        scrollToMinimumParticipants()
      }) {
        Image(systemName: "minus.circle.fill")
          .font(.system(size: 32))
          .foregroundColor(currentMinimum <= 2 ? Color(.systemGray4) : .blue)
      }
      .disabled(currentMinimum <= 2)
      
      VStack(spacing: 4) {
        Text("\(currentMinimum)명")
          .font(.system(size: 36, weight: .bold))
          .foregroundColor(.primary)
          .contentTransition(.numericText())
        
        Text("최대 \(maxParticipants)명")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity)
      
      Button(
        action: {
          store.send(
            .view(.incrementParticipants),
            animation: .spring(response: 0.3, dampingFraction: 0.7)
          )
        scrollToMinimumParticipants()
      }) {
        Image(systemName: "plus.circle.fill")
          .font(.system(size: 32))
          .foregroundColor(currentMinimum >= maxParticipants ? Color(.systemGray4) : .blue)
      }
      .disabled(currentMinimum >= maxParticipants)
    }
    .padding(.vertical, 8)
  }
  
  // MARK: - 스크롤 헬퍼
  private func scrollToMinimumParticipants() {
    if let scrollProxy = scrollProxy {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        withAnimation {
          scrollProxy.scrollTo("minimumParticipants", anchor: .center)
        }
      }
    }
  }
  
  // MARK: - 안내 박스
  private var infoBox: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 20))
        .foregroundColor(.blue)
      
      Text("최소 \(currentMinimum)명이 참석하면 약속이 자동으로 확정됩니다")
        .font(.system(size: 14))
        .foregroundColor(.primary)
        .fixedSize(horizontal: false, vertical: true)
      
      Spacer(minLength: 0)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.blue.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
  
  // MARK: - 경고 메시지
  private var warningMessage: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 14))
        .foregroundColor(.orange)
      
      Text("최소 참가 인원이 그룹 멤버 수와 같습니다. 한 명이라도 불참하면 약속이 취소됩니다.")
        .font(.system(size: 13))
        .foregroundColor(.orange)
        .fixedSize(horizontal: false, vertical: true)
      
      Spacer(minLength: 0)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.orange.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

// MARK: - Previews

#Preview("2명 그룹 (고정)") {
  MinimumParticipantsSection(
    store: Store(
      initialState: CreatePromise.Feature.State(
        promiseProposal: PromiseProposal(
          title: "영화 관람",
          emoji: "🍿",
          group: .init(
            id: "g1",
            emoji: "👥",
            title: "지민과 나",
            memberCount: 2
          ),
          startedAt: Date().addingTimeInterval(7200),
          minimumParticipants: 2
        )
      )
    ) {
      CreatePromise.Feature()
    }
  )
  .padding()
}

#Preview("4명 그룹 - 최소 2명") {
  MinimumParticipantsSection(
    store: Store(
      initialState: CreatePromise.Feature.State(
        promiseProposal: PromiseProposal(
          title: "카페 미팅",
          emoji: "☕",
          group: .init(
            id: "g2",
            emoji: "🏢",
            title: "회사 동료들",
            memberCount: 4
          ),
          startedAt: Date().addingTimeInterval(7200),
          minimumParticipants: 2
        )
      )
    ) {
      CreatePromise.Feature()
    }
  )
  .padding()
}

#Preview("5명 그룹 - 기본값 3명") {
  MinimumParticipantsSection(
    store: Store(
      initialState: CreatePromise.Feature.State(
        promiseProposal: PromiseProposal(
          title: "저녁 식사",
          emoji: "🍽️",
          group: .init(
            id: "g5",
            emoji: "🍴",
            title: "주말 모임",
            memberCount: 5
          ),
          startedAt: Date().addingTimeInterval(7200),
          minimumParticipants: 3
        )
      )
    ) {
      CreatePromise.Feature()
    }
  )
  .padding()
}

#Preview("10명 그룹 - 최대와 같음 (경고)") {
  MinimumParticipantsSection(
    store: Store(
      initialState: CreatePromise.Feature.State(
        promiseProposal: PromiseProposal(
          title: "팀 회의",
          emoji: "💼",
          group: .init(
            id: "g10",
            emoji: "🏢",
            title: "전체 팀",
            memberCount: 10
          ),
          startedAt: Date().addingTimeInterval(7200),
          minimumParticipants: 10
        )
      )
    ) {
      CreatePromise.Feature()
    }
  )
  .padding()
}

#Preview("다크모드") {
  VStack(spacing: 24) {
    MinimumParticipantsSection(
      store: Store(
        initialState: CreatePromise.Feature.State(
          promiseProposal: PromiseProposal(
            title: "저녁 식사",
            emoji: "🍽️",
            group: .init(
              id: "g6",
              emoji: "👥",
              title: "친구들",
              memberCount: 6
            ),
            startedAt: Date().addingTimeInterval(7200),
            minimumParticipants: 4
          )
        )
      ) {
        CreatePromise.Feature()
      }
    )
  }
  .padding()
  .preferredColorScheme(.dark)
}

#Preview("전체 폼") {
  ScrollView {
    VStack(spacing: 24) {
      Text("약속 만들기 - Step 3")
        .font(.title2)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity, alignment: .leading)
      
      SectionPlaceHolder(
        placeHolderTitle: "제목",
        isRequired: true
      ) {
        Text("저녁 식사")
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      
      MinimumParticipantsSection(
        store: Store(
          initialState: CreatePromise.Feature.State(
            promiseProposal: PromiseProposal(
              title: "저녁 식사",
              emoji: "🍽️",
              group: .init(
                id: "g5",
                emoji: "🍴",
                title: "주말 모임",
                memberCount: 5
              ),
              startedAt: Date().addingTimeInterval(7200),
              minimumParticipants: 3
            )
          )
        ) {
          CreatePromise.Feature()
        }
      )
    }
    .padding()
  }
}
