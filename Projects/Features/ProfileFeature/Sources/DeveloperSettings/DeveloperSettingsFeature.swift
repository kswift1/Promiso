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
      }

      public enum Internal: Sendable {
        case activityStarted(String)
        case activityEnded
        case activityFailed(String)
      }

      public enum Delegate: Sendable {}
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            state.isLiveActivityActive = !Activity<PromiseActivityAttributes>.activities.isEmpty
            if state.isLiveActivityActive {
              state.activityId = Activity<PromiseActivityAttributes>.activities.first?.id
            }
            return .none

          case .startLiveActivityTapped:
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
              state.statusMessage = "라이브액티비티 비활성화됨"
              return .none
            }

            let attributes = PromiseActivityAttributes(
              promiseId: "test-\(UUID().uuidString.prefix(8))",
              currentUserId: "user-1",
              emoji: "🍜",
              title: "점심 모임 테스트용 긴 제목입니다",
              location: "강남역 11번 출구 긴 위치 테스트",
              scheduledTime: Date().addingTimeInterval(1800)
            )

            let contentState = PromiseActivityAttributes.ContentState(
              trackingDurationMinutes: 30,
              participants: [
                ParticipantState(id: "user-1", name: "일이삼사오육칠", estimatedArrivalMinutes: nil),
                ParticipantState(id: "user-2", name: "가나다라마바사", estimatedArrivalMinutes: nil),
                ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: nil),
                ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: nil),
              ]
            )

            return .run { send in
              do {
                let activity = try Activity.request(
                  attributes: attributes,
                  content: ActivityContent(state: contentState, staleDate: nil),
                  pushType: nil
                )
                await send(.internal(.activityStarted(activity.id)))
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
          }

        case .internal(let internalAction):
          switch internalAction {
          case .activityStarted(let id):
            state.activityId = id
            state.isLiveActivityActive = true
            state.statusMessage = "시작됨"
            return .none

          case .activityEnded:
            state.isLiveActivityActive = false
            state.activityId = nil
            state.statusMessage = "종료됨"
            return .none

          case .activityFailed(let error):
            state.statusMessage = "실패: \(error)"
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      List {
        // MARK: - Live Activity Section
        Section {
          VStack(alignment: .leading, spacing: 12) {
            // 상태
            HStack {
              Text("상태")
                .foregroundStyle(.secondary)
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
              } else {
                Text("비활성")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }

            // 상태 메시지
            if !store.statusMessage.isEmpty {
              Text(store.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // 버튼
            if store.isLiveActivityActive {
              Button {
                store.send(.view(.endLiveActivityTapped))
              } label: {
                Label("종료", systemImage: "stop.circle.fill")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
              .tint(.red)
            } else {
              Button {
                store.send(.view(.startLiveActivityTapped))
              } label: {
                Label("라이브액티비티 시작", systemImage: "play.circle.fill")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
              .tint(.purple)
            }
          }
          .padding(.vertical, 8)
        } header: {
          Text("라이브 액티비티 테스트")
        } footer: {
          Text("테스트용 라이브 액티비티를 시작/종료할 수 있습니다. 실제 위치 추적은 하지 않습니다.")
        }

        // MARK: - Debug Info Section
        Section {
          LabeledContent("Activity ID", value: store.activityId ?? "-")
          LabeledContent("활성 액티비티 수", value: "\(Activity<PromiseActivityAttributes>.activities.count)")
        } header: {
          Text("디버그 정보")
        }
      }
      .navigationTitle("개발자 설정")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }
  }
}
