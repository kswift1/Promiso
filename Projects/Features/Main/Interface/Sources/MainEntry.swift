import SwiftUI

//public struct MainEntry {
//  public var makeView: (_ config: Config) -> AnyView
//  public init(makeView: @escaping (_ config: Config) -> AnyView) { self.makeView = makeView }
//}
//
//public struct Config: Sendable { public init() {} }
//public enum MainRoute: Hashable { case root }
//
//// Feature/Main/Interface/Sources/MainFeatureInterface.swift
import ComposableArchitecture
import SwiftUI
//import HomeFeatureInterface
//import ProposalFeatureInterface
//import CalendarFeatureInterface
//import GroupFeatureInterface

// MARK: - Public State
public struct MainState: Equatable {
    // Tab Management
    public var selectedTab: Tab = .home
    
    // Child Feature States (Public)
    public var home: HomeState
    public var proposal: ProposalState
    public var calendar: CalendarState
    public var group: GroupState
    
    // Navigation
    public var destination: MainDestination?
    
    // Badge Counts
    public var proposalBadgeCount: Int = 0
    public var notificationBadgeCount: Int = 0
    
    // Tab Definition
    public enum Tab: String, CaseIterable, Equatable {
        case home = "홈"
        case proposal = "제안"
        case calendar = "캘린더"
        case group = "그룹"
        
        public var icon: String {
            switch self {
            case .home: return "house.fill"
            case .proposal: return "bubble.left.and.bubble.right.fill"
            case .calendar: return "calendar"
            case .group: return "person.2.fill"
            }
        }
    }
    
    // Public Initializer
    public init(
        selectedTab: Tab = .home,
        home: HomeState = .init(),
        proposal: ProposalState = .init(),
        calendar: CalendarState = .init(),
        group: GroupState = .init(),
        destination: MainDestination? = nil,
        proposalBadgeCount: Int = 0,
        notificationBadgeCount: Int = 0
    ) {
        self.selectedTab = selectedTab
        self.home = home
        self.proposal = proposal
        self.calendar = calendar
        self.group = group
        self.destination = destination
        self.proposalBadgeCount = proposalBadgeCount
        self.notificationBadgeCount = notificationBadgeCount
    }
}

// MARK: - Public Action
public enum MainAction: Equatable {
    // Tab Selection
    case tabSelected(MainState.Tab)
    
    // Child Actions (Public)
    case home(HomeAction)
    case proposal(ProposalAction)
    case calendar(CalendarAction)
    case group(GroupAction)
    
    // Navigation
    case setDestination(MainDestination?)
    case destination(MainDestinationAction)
    
    // Global Events
//    case pushNotificationReceived(PushNotification)
    case deepLinkOpened(URL)
    case updateBadgeCounts
    
    // Quick Actions (from child features)
    case navigateToNewProposal
    case navigateToPromiseDetail(Promise.ID)
}

// MARK: - Destination
public enum MainDestination: Equatable {
    case newProposal(NewProposalState)
    case promiseDetail(PromiseDetailState)
    case settings(SettingsState)
    case liveActivity(LiveActivityState)
}

public enum MainDestinationAction: Equatable {
    case newProposal(NewProposalAction)
    case promiseDetail(PromiseDetailAction)
    case settings(SettingsAction)
    case liveActivity(LiveActivityAction)
}

// MARK: - Interface Protocol
public protocol MainFeatureInterface {
    var reducer: AnyReducer<MainState, MainAction> { get }
    func makeView(store: StoreOf<MainReducer>) -> AnyView
}

// MARK: - Factory Protocol
public protocol MainFeatureFactoryProtocol {
    static func make() -> MainFeatureInterface
}
