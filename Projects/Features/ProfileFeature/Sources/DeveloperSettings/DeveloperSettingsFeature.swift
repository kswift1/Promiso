// MARK: - DeveloperSettingsFeature.swift
// 개발자 설정 화면 Feature (#if DEBUG 전용)

import ActivityKit
import ComposableArchitecture
import PromisoShared
import SwiftUI

// MARK: - Feature Namespace

/// 개발자 설정 Feature 컴포넌트를 위한 Namespace
public enum DeveloperSettings {}

// MARK: - Feature Implementation

extension DeveloperSettings {

  // MARK: - Reducer

  @Reducer
  public struct Feature {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 라이브 액티비티 활성 상태
      var isLiveActivityActive: Bool = false
      /// 현재 활성 액티비티 ID
      var activityId: String?
      /// 상태 메시지
      var statusMessage: String = ""
      /// 현재 ContentState
      var currentContentState: PromiseActivityAttributes.ContentState?

      public init() {}
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum View: Sendable {
        case onAppear
        case startLiveActivityTapped
        case endLiveActivityTapped
        // 개별 참가자 ETA 업데이트
        case updateParticipantETA(id: String, eta: Int?)
        // 시나리오 테스트
        case allWaitingTapped
        case allDepartedTapped
        case allArrivedTapped
        case groupingTestTapped
        case sequentialArrivalTapped
        case mixedStatusTapped
      }

      public enum Internal: Sendable, Equatable {
        case activityStarted(String, PromiseActivityAttributes.ContentState)
        case activityEnded
        case activityFailed(String)
        case activityUpdated(PromiseActivityAttributes.ContentState)
      }

      public enum Delegate: Sendable {}
    }

    // MARK: - Mock Data

    private static let mockUserId1 = "KrALQyaaUScWRFCUTpWN2XDHnpm1"
    private static let mockUserId2 = "kWJYVOGRMWX65UyQOcznRti3lMR2"
    private static let mockUserId3 = "user-3"
    private static let mockUserId4 = "user-4"

    private static let mockParticipants = [
      ParticipantState(id: mockUserId1, name: "일이삼사오육칠", estimatedArrivalMinutes: nil),
      ParticipantState(id: mockUserId2, name: "가나다라마바사", estimatedArrivalMinutes: nil),
      ParticipantState(id: mockUserId3, name: "지현", estimatedArrivalMinutes: nil),
      ParticipantState(id: mockUserId4, name: "서연", estimatedArrivalMinutes: nil),
    ]

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            if let activity = Activity<PromiseActivityAttributes>.activities.first {
              state.isLiveActivityActive = true
              state.activityId = activity.id
              state.currentContentState = activity.content.state
              state.statusMessage = "기존 활동: \(activity.id.prefix(8))..."
            }
            return .none

          case .startLiveActivityTapped:
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
              state.statusMessage = "라이브액티비티 비활성화됨"
              return .none
            }

            // 디버그: 캐시된 프로필 이미지 파일 목록 출력
            let cachedFiles = LiveActivityImageStore.listCachedFiles()
            AppLogger.liveActivity.debug("캐시된 파일: \(cachedFiles)")

            let attributes = PromiseActivityAttributes(
              promiseId: "mock-\(UUID().uuidString.prefix(8))",
              currentUserId: Self.mockUserId1,
              emoji: "🍜",
              title: "점심 모임",
              location: "강남역 11번 출구",
              scheduledTime: Date().addingTimeInterval(1800)
            )

            let initialState = PromiseActivityAttributes.ContentState(
              trackingDurationMinutes: 30,
              participants: Self.mockParticipants
            )

            return .run { send in
              do {
                let activity = try Activity.request(
                  attributes: attributes,
                  content: ActivityContent(state: initialState, staleDate: nil),
                  pushType: nil
                )
                await send(.internal(.activityStarted(activity.id, initialState)))
              } catch {
                await send(.internal(.activityFailed(error.localizedDescription)))
              }
            }

          case .endLiveActivityTapped:
            return .run { send in
              for activity in Activity<PromiseActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
              }
              await send(.internal(.activityEnded))
            }

          case .updateParticipantETA(let id, let eta):
            guard let activityId = state.activityId,
                  let currentState = state.currentContentState else { return .none }

            let updatedState = currentState.updating(participantId: id, estimatedArrivalMinutes: eta)
            let etaText = eta.map { $0 == 0 ? "도착" : "\($0)분" } ?? "대기"
            state.statusMessage = "\(id.prefix(8)) → \(etaText)"

            return .run { send in
              try? await Task.sleep(for: .seconds(1))
              if let activity = Activity<PromiseActivityAttributes>.activities
                .first(where: { $0.id == activityId })
              {
                await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                await send(.internal(.activityUpdated(updatedState)))
              }
            }

          case .allWaitingTapped:
            return updateAllParticipants(state: &state, eta: nil, message: "모두 → 대기")

          case .allDepartedTapped:
            return updateAllParticipants(state: &state, eta: 15, message: "모두 → 15분")

          case .allArrivedTapped:
            return updateAllParticipants(state: &state, eta: 0, message: "모두 → 도착")

          case .groupingTestTapped:
            guard let activityId = state.activityId,
                  let currentState = state.currentContentState else { return .none }

            var participants = currentState.participants
            for i in participants.indices {
              let eta: Int?
              switch i {
              case 0, 1: eta = 10
              case 2: eta = 5
              default: eta = nil
              }
              participants[i] = participants[i].with(estimatedArrivalMinutes: eta)
            }
            let updatedState = PromiseActivityAttributes.ContentState(
              trackingDurationMinutes: currentState.trackingDurationMinutes,
              participants: participants
            )
            state.statusMessage = "그룹화 테스트"

            return .run { send in
              try? await Task.sleep(for: .seconds(1))
              if let activity = Activity<PromiseActivityAttributes>.activities
                .first(where: { $0.id == activityId })
              {
                await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                await send(.internal(.activityUpdated(updatedState)))
              }
            }

          case .sequentialArrivalTapped:
            guard let activityId = state.activityId,
                  state.currentContentState != nil else { return .none }

            state.statusMessage = "순차 도착 시작..."

            return .run { send in
              let userIds = [Self.mockUserId1, Self.mockUserId2, Self.mockUserId3, Self.mockUserId4]
              let etaSequence: [Int?] = [15, 10, 5, 0]

              for (index, userId) in userIds.enumerated() {
                try? await Task.sleep(for: .seconds(1.5))

                if let activity = Activity<PromiseActivityAttributes>.activities
                  .first(where: { $0.id == activityId })
                {
                  let currentState = activity.content.state
                  let updatedState = currentState.updating(
                    participantId: userId, estimatedArrivalMinutes: etaSequence[index])
                  await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                  await send(.internal(.activityUpdated(updatedState)))
                }
              }
            }

          case .mixedStatusTapped:
            guard let activityId = state.activityId,
                  let currentState = state.currentContentState else { return .none }

            var participants = currentState.participants
            let etas: [Int?] = [0, 5, 15, nil]
            for i in participants.indices {
              participants[i] = participants[i].with(estimatedArrivalMinutes: etas[i])
            }
            let updatedState = PromiseActivityAttributes.ContentState(
              trackingDurationMinutes: currentState.trackingDurationMinutes,
              participants: participants
            )
            state.statusMessage = "혼합 상태"

            return .run { send in
              try? await Task.sleep(for: .seconds(1))
              if let activity = Activity<PromiseActivityAttributes>.activities
                .first(where: { $0.id == activityId })
              {
                await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                await send(.internal(.activityUpdated(updatedState)))
              }
            }
          }

        case .internal(let internalAction):
          switch internalAction {
          case .activityStarted(let id, let contentState):
            state.activityId = id
            state.currentContentState = contentState
            state.isLiveActivityActive = true
            state.statusMessage = "시작됨: \(id.prefix(8))..."
            return .none

          case .activityEnded:
            state.isLiveActivityActive = false
            state.activityId = nil
            state.currentContentState = nil
            state.statusMessage = "종료됨"
            return .none

          case .activityFailed(let error):
            state.statusMessage = "실패: \(error)"
            return .none

          case .activityUpdated(let contentState):
            state.currentContentState = contentState
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }

    // MARK: - Helpers

    private func updateAllParticipants(state: inout State, eta: Int?, message: String) -> Effect<
      Action
    > {
      guard let activityId = state.activityId,
        let currentState = state.currentContentState
      else { return .none }

      var participants = currentState.participants
      for i in participants.indices {
        participants[i] = participants[i].with(estimatedArrivalMinutes: eta)
      }
      let updatedState = PromiseActivityAttributes.ContentState(
        trackingDurationMinutes: currentState.trackingDurationMinutes,
        participants: participants
      )
      state.statusMessage = message

      return .run { send in
        try? await Task.sleep(for: .seconds(1))
        if let activity = Activity<PromiseActivityAttributes>.activities
          .first(where: { $0.id == activityId })
        {
          await activity.update(ActivityContent(state: updatedState, staleDate: nil))
          await send(.internal(.activityUpdated(updatedState)))
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    private static let mockUserId1 = "KrALQyaaUScWRFCUTpWN2XDHnpm1"
    private static let mockUserId2 = "kWJYVOGRMWX65UyQOcznRti3lMR2"
    private static let mockUserId3 = "user-3"
    private static let mockUserId4 = "user-4"

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          // MARK: - Live Activity Section
          liveActivitySection

          // MARK: - Debug Info Section
          debugInfoSection
        }
        .padding(16)
      }
      .navigationTitle("개발자 설정")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Live Activity Section

    private var liveActivitySection: some View {
      VStack(spacing: 12) {
        // 헤더
        HStack {
          Text("🧪 라이브액티비티 테스트")
            .font(.headline)
          Spacer()
          if store.isLiveActivityActive {
            Text("활성")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(.green)
              .clipShape(Capsule())
          }
        }

        // 상태 메시지
        if !store.statusMessage.isEmpty {
          Text(store.statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .clipShape(Capsule())
        }

        if store.isLiveActivityActive {
          activeControlsSection
        } else {
          inactiveSection
        }
      }
      .padding(16)
      .background(Color.purple.opacity(0.05))
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.purple.opacity(0.2), lineWidth: 1)
      )
    }

    // MARK: - Active Controls

    private var activeControlsSection: some View {
      VStack(spacing: 12) {
        // 개별 참가자 ETA 설정
        Text("개별 ETA 설정")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)

        VStack(spacing: 6) {
          participantETARow(name: "나", id: Self.mockUserId1)
          participantETARow(name: "민수", id: Self.mockUserId2)
          participantETARow(name: "지현", id: Self.mockUserId3)
          participantETARow(name: "서연", id: Self.mockUserId4)
        }

        Divider().padding(.vertical, 4)

        // 시나리오 테스트
        Text("시나리오 테스트")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)

        LazyVGrid(
          columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
          ], spacing: 8
        ) {
          scenarioButton(title: "모두 대기", color: .gray) {
            store.send(.view(.allWaitingTapped))
          }
          scenarioButton(title: "모두 출발(15분)", color: .indigo) {
            store.send(.view(.allDepartedTapped))
          }
          scenarioButton(title: "모두 도착", color: .green) {
            store.send(.view(.allArrivedTapped))
          }
          scenarioButton(title: "그룹화 테스트", color: .orange) {
            store.send(.view(.groupingTestTapped))
          }
          scenarioButton(title: "순차 도착", color: .blue) {
            store.send(.view(.sequentialArrivalTapped))
          }
          scenarioButton(title: "혼합 상태", color: .purple) {
            store.send(.view(.mixedStatusTapped))
          }
        }

        Divider().padding(.vertical, 4)

        // 종료 버튼
        Button {
          store.send(.view(.endLiveActivityTapped))
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "stop.circle.fill")
            Text("라이브액티비티 종료")
          }
          .font(.system(size: 14, weight: .semibold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(Color.red.opacity(0.1))
          .foregroundStyle(.red)
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
      }
    }

    // MARK: - Inactive Section

    private var inactiveSection: some View {
      VStack(spacing: 12) {
        Button {
          store.send(.view(.startLiveActivityTapped))
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
            Text("목 라이브액티비티 시작")
          }
          .font(.system(size: 16, weight: .semibold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(Color.purple)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        Text("30분 후 약속, 4명 참가자 목 데이터로 시작")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
    }

    // MARK: - Debug Info Section

    private var debugInfoSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("디버그 정보")
          .font(.headline)

        VStack(spacing: 8) {
          debugRow(label: "Activity ID", value: store.activityId ?? "-")
          debugRow(
            label: "활성 액티비티 수",
            value: "\(Activity<PromiseActivityAttributes>.activities.count)")

          if let state = store.currentContentState {
            debugRow(label: "추적 시간", value: "\(state.trackingDurationMinutes)분")
            debugRow(label: "참가자 수", value: "\(state.participants.count)명")
          }
        }
      }
      .padding(16)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helper Views

    private func participantETARow(name: String, id: String) -> some View {
      HStack(spacing: 6) {
        Text(name)
          .font(.system(size: 12, weight: .medium))
          .frame(width: 36, alignment: .leading)

        ForEach(etaOptions, id: \.label) { option in
          Button {
            store.send(.view(.updateParticipantETA(id: id, eta: option.value)))
          } label: {
            Text(option.label)
              .font(.system(size: 10, weight: .medium))
              .padding(.horizontal, 6)
              .padding(.vertical, 4)
              .background(option.color.opacity(0.15))
              .foregroundStyle(option.color)
              .clipShape(RoundedRectangle(cornerRadius: 4))
          }
        }
      }
    }

    private var etaOptions: [(label: String, value: Int?, color: Color)] {
      [
        ("대기", nil, .gray),
        ("30분", 30, .orange),
        ("15분", 15, .yellow),
        ("10분", 10, .blue),
        ("5분", 5, .indigo),
        ("도착", 0, .green),
      ]
    }

    private func scenarioButton(title: String, color: Color, action: @escaping () -> Void)
      -> some View
    {
      Button(action: action) {
        Text(title)
          .font(.system(size: 12, weight: .medium))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(color.opacity(0.1))
          .foregroundStyle(color)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }

    private func debugRow(label: String, value: String) -> some View {
      HStack {
        Text(label)
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
        Spacer()
        Text(value)
          .font(.system(size: 13, design: .monospaced))
      }
    }
  }
}
