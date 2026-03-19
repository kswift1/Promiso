// MARK: - CalendarImportFeature.swift
// 온보딩 → 캘린더 가져오기

import ComposableArchitecture
import Clients
import PromisoShared
import Foundation

extension AppEntry {

  @Reducer
  public struct CalendarImport {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      var nickname: String
      var phase: Phase = .idle
      var calendarGroups: [CalendarGroup] = []
      var selectedEventIds: Set<String> = []
      var expandedCalendarNames: Set<String> = []
      var importProgress: Int = 0
      var importTotal: Int = 0

      public enum ResultType: Equatable {
        case noEvents
        case imported(Int)
        case failed
      }

      public enum Phase: Equatable {
        case idle
        case requesting
        case scanning
        case selecting
        case uploading
        case result(ResultType)
        case completed
      }

      var selectedEventCount: Int {
        selectedEventIds.count
      }

      public init(nickname: String) {
        self.nickname = nickname
      }
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(InternalAction)
      case delegate(DelegateAction)

      @CasePathable
      public enum ViewAction: Sendable {
        case importTapped
        case laterTapped
        case calendarToggled(String)
        case calendarExpandToggled(String)
        case eventToggled(String)
        case confirmImportTapped
        case startTapped
      }

      @CasePathable
      public enum InternalAction: Sendable {
        case permissionResponse(Bool)
        case eventsFetched([CalendarEvent])
        case importCompleted(CalendarImportResult)
        case importFailed
        case uploadProgressUpdated(Int)
      }

      public enum DelegateAction: Equatable, Sendable {
        case completed
      }
    }

    // MARK: - Dependencies

    @Dependency(\.eventKitClient) var eventKitClient
    @Dependency(\.personalEventClient) var personalEventClient

    // MARK: - Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .importTapped:
            state.phase = .requesting
            return .run { send in
              let granted = (try? await eventKitClient.requestAccess()) ?? false
              await send(.internal(.permissionResponse(granted)))
            }

          case .laterTapped:
            return .send(.delegate(.completed))

          case .calendarToggled(let name):
            guard let group = state.calendarGroups.first(where: { $0.calendarName == name }) else { return .none }
            let groupEventIds = Set(group.events.map(\.id))
            let allSelected = groupEventIds.isSubset(of: state.selectedEventIds)
            if allSelected {
              state.selectedEventIds.subtract(groupEventIds)
            } else {
              state.selectedEventIds.formUnion(groupEventIds)
            }
            return .none

          case .calendarExpandToggled(let name):
            if state.expandedCalendarNames.contains(name) {
              state.expandedCalendarNames.remove(name)
            } else {
              state.expandedCalendarNames.insert(name)
            }
            return .none

          case .eventToggled(let eventId):
            if state.selectedEventIds.contains(eventId) {
              state.selectedEventIds.remove(eventId)
            } else {
              state.selectedEventIds.insert(eventId)
            }
            return .none

          case .startTapped:
            state.phase = .completed
            return .send(.delegate(.completed))

          case .confirmImportTapped:
            let selectedEvents = state.calendarGroups
              .flatMap(\.events)
              .filter { state.selectedEventIds.contains($0.id) }

            guard !selectedEvents.isEmpty else {
              state.phase = .result(.noEvents)
              return .none
            }

            state.phase = .uploading
            state.importTotal = selectedEvents.count
            state.importProgress = 0

            return .run { send in
              let calendar = Calendar.current
              let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? Date()

              let batchSize = 10
              var successCount = 0

              for batchStart in stride(from: 0, to: selectedEvents.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, selectedEvents.count)
                let batch = Array(selectedEvents[batchStart..<batchEnd])

                await withTaskGroup(of: Bool.self) { group in
                  for event in batch {
                    group.addTask {
                      let model = Self.toPersonalEventModel(event)
                      do {
                        _ = try await personalEventClient.createEvent(model)
                        return true
                      } catch {
                        return false
                      }
                    }
                  }

                  for await success in group {
                    if success {
                      successCount += 1
                    }
                  }
                }

                await send(.internal(.uploadProgressUpdated(successCount)))
              }

              let thisWeekCount = selectedEvents.filter { $0.startDate >= startOfWeek && $0.startDate < endOfWeek }.count
              let result = CalendarImportResult(totalImported: successCount, thisWeekCount: thisWeekCount)
              await send(.internal(.importCompleted(result)))
            }

          }

        case .internal(let internalAction):
          switch internalAction {
          case .permissionResponse(let granted):
            guard granted else {
              return .send(.delegate(.completed))
            }

            state.phase = .scanning
            return .run { send in
              let calendar = Calendar.current
              let startDate = calendar.startOfDay(for: Date())
              let endDate = calendar.date(byAdding: .year, value: 1, to: startDate) ?? Date()
              do {
                let events = try await eventKitClient.fetchEvents(startDate, endDate)
                await send(.internal(.eventsFetched(events)))
              } catch {
                await send(.internal(.importFailed))
              }
            }

          case .eventsFetched(let events):
            let filteredEvents = events.filter { event in
              let name = event.calendarName.lowercased()
              return name != "birthdays" && name != "생일"
            }
            let groups = CalendarGroup.groupBy(filteredEvents)

            guard !groups.isEmpty else {
              state.phase = .result(.noEvents)
              return .none
            }

            state.calendarGroups = groups
            state.selectedEventIds = Set(filteredEvents.map(\.id))
            state.expandedCalendarNames = Set(groups.map(\.calendarName))
            state.phase = .selecting
            return .none

          case .uploadProgressUpdated(let count):
            state.importProgress = count
            return .none

          case .importCompleted(let result):
            if result.totalImported > 0 {
              state.phase = .result(.imported(result.totalImported))
            } else {
              state.phase = .result(.failed)
            }
            return .none

          case .importFailed:
            state.phase = .result(.failed)
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }

    // MARK: - Helpers

    private static func toPersonalEventModel(_ event: CalendarEvent) -> PersonalEventModel {
      let title = String(event.displayTitle.prefix(30))
      return PersonalEventModel(
        id: UUID().uuidString,
        title: title.isEmpty ? "일정" : title,
        emoji: event.displayEmoji,
        description: nil,
        startAt: event.startDate,
        endAt: event.isAllDay ? nil : event.endDate,
        location: event.location.map { LocationInfoModel(name: $0) },
        imageUrls: [],
        reminderMinutesBefore: nil,
        createdAt: Date(),
        updatedAt: Date()
      )
    }
  }
}

// MARK: - CalendarGroup

public struct CalendarGroup: Equatable, Identifiable, Sendable {
  public var id: String { calendarName }
  public let calendarName: String
  public let calendarColorHex: String
  public let events: [CalendarEvent]
  public var eventCount: Int { events.count }

  public static func groupBy(_ events: [CalendarEvent]) -> [CalendarGroup] {
    Dictionary(grouping: events, by: \.calendarName)
      .map { CalendarGroup(calendarName: $0.key, calendarColorHex: $0.value.first?.calendarColorHex ?? "#808080", events: $0.value.sorted { $0.startDate < $1.startDate }) }
      .sorted { $0.eventCount > $1.eventCount }
  }
}
