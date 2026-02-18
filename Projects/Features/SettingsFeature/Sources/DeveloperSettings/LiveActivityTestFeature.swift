// MARK: - LiveActivityTestFeature.swift
// 라이브 액티비티 테스트 화면 Feature

import ActivityKit
import ComposableArchitecture
import PromisoShared
import SwiftUI

// MARK: - Feature Namespace

public enum LiveActivityTest {}

// MARK: - Feature Implementation

extension LiveActivityTest {

  @Reducer
  public struct Feature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
      var isLiveActivityActive: Bool = false
      var activityId: String?
      var statusMessage: String = ""
      var currentContentState: PromiseActivityAttributes.ContentState?
      var currentAttributes: PromiseActivityAttributes?

      public init() {}
    }

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)

      @CasePathable
      public enum View: Sendable {
        case onAppear
        case startLiveActivityTapped
        case endLiveActivityTapped
        case updateParticipantETA(id: String, eta: Int?)
        case allWaitingTapped
        case allDepartedTapped
        case allArrivedTapped
        case groupingTestTapped
        case sequentialArrivalTapped
        case mixedStatusTapped
      }

      public enum Internal: Sendable, Equatable {
        case activityStarted(String, PromiseActivityAttributes, PromiseActivityAttributes.ContentState)
        case activityEnded
        case activityFailed(String)
        case activityUpdated(PromiseActivityAttributes.ContentState)
      }
    }

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

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            if let activity = Activity<PromiseActivityAttributes>.activities.first {
              state.isLiveActivityActive = true
              state.activityId = activity.id
              state.currentAttributes = activity.attributes
              state.currentContentState = activity.content.state
              state.statusMessage = "\(LocalizedStrings.SettingsStrings.existingActivity)\(activity.id.prefix(8))..."
            }
            return .none

          case .startLiveActivityTapped:
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
              state.statusMessage = LocalizedStrings.SettingsStrings.liveActivityDisabled
              return .none
            }

            let cachedFiles = LiveActivityImageStore.listCachedFiles()
            AppLogger.liveActivity.debug("\(LocalizedStrings.SettingsStrings.cachedFiles)\(cachedFiles)")

            let attributes = PromiseActivityAttributes(
              promiseId: "mock-\(UUID().uuidString.prefix(8))",
              currentUserId: Self.mockUserId1,
              emoji: "🍜",
              title: LocalizedStrings.SettingsStrings.mockMeeting,
              location: LocalizedStrings.SettingsStrings.mockLocation,
              latitude: 37.498095,
              longitude: 127.027610,
              scheduledTime: Date().addingTimeInterval(1800)
            )

            let initialState = PromiseActivityAttributes.ContentState(
              trackingDurationMinutes: 30,
              participants: Self.mockParticipants
            )

            return .run { [attributes] send in
              do {
                let activity = try Activity.request(
                  attributes: attributes,
                  content: ActivityContent(state: initialState, staleDate: nil),
                  pushType: nil
                )
                await send(.internal(.activityStarted(activity.id, attributes, initialState)))
              } catch {
                await send(.internal(.activityFailed(LocalizedStrings.Error.unknownError)))
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
            let etaText = eta.map { $0 == 0 ? LocalizedStrings.SettingsStrings.arrived : "\($0)\(LocalizedStrings.SettingsStrings.minutes)" } ?? LocalizedStrings.SettingsStrings.waiting
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
            return updateAllParticipants(state: &state, eta: nil, message: LocalizedStrings.SettingsStrings.allToWaiting)

          case .allDepartedTapped:
            return updateAllParticipants(state: &state, eta: 15, message: LocalizedStrings.SettingsStrings.allTo15Min)

          case .allArrivedTapped:
            return updateAllParticipants(state: &state, eta: 0, message: LocalizedStrings.SettingsStrings.allToArrived)

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
            state.statusMessage = LocalizedStrings.SettingsStrings.groupingTest

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

            state.statusMessage = LocalizedStrings.SettingsStrings.sequentialArrivalStarting

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
            state.statusMessage = LocalizedStrings.SettingsStrings.mixedStatus

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
          case .activityStarted(let id, let attributes, let contentState):
            state.activityId = id
            state.currentAttributes = attributes
            state.currentContentState = contentState
            state.isLiveActivityActive = true
            state.statusMessage = "\(LocalizedStrings.SettingsStrings.started)\(id.prefix(8))..."
            return .none

          case .activityEnded:
            state.isLiveActivityActive = false
            state.activityId = nil
            state.currentAttributes = nil
            state.currentContentState = nil
            state.statusMessage = LocalizedStrings.SettingsStrings.ended
            return .none

          case .activityFailed(let error):
            state.statusMessage = "\(LocalizedStrings.SettingsStrings.failed)\(error)"
            return .none

          case .activityUpdated(let contentState):
            state.currentContentState = contentState
            return .none
          }
        }
      }
    }

    private func updateAllParticipants(state: inout State, eta: Int?, message: String) -> Effect<Action> {
      guard let activityId = state.activityId,
            let currentState = state.currentContentState else { return .none }

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
          liveActivitySection
          debugInfoSection
        }
        .padding(16)
      }
      .navigationTitle(LocalizedStrings.SettingsStrings.liveActivityTestTitle)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private var liveActivitySection: some View {
      VStack(spacing: 12) {
        HStack {
          Text(LocalizedStrings.SettingsStrings.liveActivityTestHeader)
            .font(.headline)
          Spacer()
          if store.isLiveActivityActive {
            Text(LocalizedStrings.SettingsStrings.active)
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(.green)
              .clipShape(Capsule())
          }
        }

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

    private var activeControlsSection: some View {
      VStack(spacing: 12) {
        Text(LocalizedStrings.SettingsStrings.individualETASettings)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)

        VStack(spacing: 6) {
          participantETARow(name: LocalizedStrings.SettingsStrings.me, id: Self.mockUserId1)
          participantETARow(name: LocalizedStrings.SettingsStrings.mockNameMinsu, id: Self.mockUserId2)
          participantETARow(name: LocalizedStrings.SettingsStrings.mockNameJihyun, id: Self.mockUserId3)
          participantETARow(name: LocalizedStrings.SettingsStrings.mockNameSeoyeon, id: Self.mockUserId4)
        }

        Divider().padding(.vertical, 4)

        Text(LocalizedStrings.SettingsStrings.scenarioTest)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
          scenarioButton(title: LocalizedStrings.SettingsStrings.allWaiting, color: .gray) {
            store.send(.view(.allWaitingTapped))
          }
          scenarioButton(title: LocalizedStrings.SettingsStrings.allDeparted15Min, color: .indigo) {
            store.send(.view(.allDepartedTapped))
          }
          scenarioButton(title: LocalizedStrings.SettingsStrings.allArrived, color: .green) {
            store.send(.view(.allArrivedTapped))
          }
          scenarioButton(title: LocalizedStrings.SettingsStrings.groupingTest, color: .orange) {
            store.send(.view(.groupingTestTapped))
          }
          scenarioButton(title: LocalizedStrings.SettingsStrings.sequentialArrival, color: .blue) {
            store.send(.view(.sequentialArrivalTapped))
          }
          scenarioButton(title: LocalizedStrings.SettingsStrings.mixedStatus, color: .purple) {
            store.send(.view(.mixedStatusTapped))
          }
        }

        Divider().padding(.vertical, 4)

        Button {
          store.send(.view(.endLiveActivityTapped))
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "stop.circle.fill")
            Text(LocalizedStrings.SettingsStrings.endLiveActivity)
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

    private var inactiveSection: some View {
      VStack(spacing: 12) {
        Button {
          store.send(.view(.startLiveActivityTapped))
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
            Text(LocalizedStrings.SettingsStrings.startMockLiveActivity)
          }
          .font(.system(size: 16, weight: .semibold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(Color.purple)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        Text(LocalizedStrings.SettingsStrings.mockDescription)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
    }

    private var debugInfoSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text(LocalizedStrings.SettingsStrings.debugInfo)
          .font(.headline)

        VStack(spacing: 8) {
          debugRow(label: LocalizedStrings.SettingsStrings.activityId, value: store.activityId ?? "-")
          debugRow(
            label: LocalizedStrings.SettingsStrings.activeActivityCount,
            value: "\(Activity<PromiseActivityAttributes>.activities.count)")

          if let attributes = store.currentAttributes {
            debugRow(label: LocalizedStrings.SettingsStrings.location, value: attributes.location ?? "-")
            if let lat = attributes.latitude, let lng = attributes.longitude {
              debugRow(label: LocalizedStrings.SettingsStrings.coordinates, value: String(format: "%.4f, %.4f", lat, lng))
            } else {
              debugRow(label: LocalizedStrings.SettingsStrings.coordinates, value: "-")
            }
          }

          if let state = store.currentContentState {
            debugRow(label: LocalizedStrings.SettingsStrings.trackingTime, value: "\(state.trackingDurationMinutes)\(LocalizedStrings.SettingsStrings.minutes)")
            debugRow(label: LocalizedStrings.SettingsStrings.participantCount, value: "\(state.participants.count)")
          }
        }
      }
      .padding(16)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }

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
        (LocalizedStrings.SettingsStrings.waiting, nil, .gray),
        (LocalizedStrings.SettingsStrings.eta30Min, 30, .orange),
        (LocalizedStrings.SettingsStrings.eta15Min, 15, .yellow),
        (LocalizedStrings.SettingsStrings.eta10Min, 10, .blue),
        (LocalizedStrings.SettingsStrings.eta5Min, 5, .indigo),
        (LocalizedStrings.SettingsStrings.arrived, 0, .green),
      ]
    }

    private func scenarioButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
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
