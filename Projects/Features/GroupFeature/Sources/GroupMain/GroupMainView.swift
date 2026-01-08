import SwiftUI
import ComposableArchitecture

extension GroupMain {
  public struct RootView: View {
    @Bindable private var store: StoreOf<GroupMain.Feature>
    @SwiftUI.Environment(\.scenePhase) private var scenePhase: ScenePhase

    public init(store: StoreOf<GroupMain.Feature>) {
      self.store = store
    }
    
    public var body: some View {
      NavigationStackStore(
        store.scope(state: \.path, action: \.path)) {
          rootContent
        } destination: { store in
          switch store.case {
          case .manageGroupFeature(let manageGroupStore):
            ManageGroup.RootView(store: manageGroupStore)
          case .promiseDetail(let promiseDetailStore):
            PromiseDetail.RootView(store: promiseDetailStore)
          case .pastPromises(let pastPromisesStore):
            PastPromises.RootView(store: pastPromisesStore)
          case .pastPromiseDetail(let pastPromiseDetailStore):
            PastPromiseDetail.RootView(store: pastPromiseDetailStore)
          }
        }
    }
    
    @ViewBuilder
    private var rootContent: some View {
      Group {
        if store.shouldShowEmptyGroupView {
          groupDetailEmptyView
        } else {
          groupDetailView
        }
      }
      .auroraBackground()
      .toolbarVisibility(.visible, for: .navigationBar)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent }
      .onAppear { store.send(.view(.onAppear)) }
      .fullScreenCover(
        store: store.scope(state: \.$createPromise, action: \.createPromise)
      ) { childStore in
        CreatePromise.RootView(store: childStore)
      }
      .fullScreenCover(
        store: store.scope(state: \.$createGroup, action: \.createGroup)
      ) { childStore in
        NavigationStack {
          CreateGroup.RootView(store: childStore)
        }
      }
      .fullScreenCover(
        store: store.scope(state: \.$joinGroup, action: \.joinGroup)
      ) { childStore in
        NavigationStack {
          JoinGroup.RootView(store: childStore)
        }
      }
      .sheet(item: Binding(
        get: { store.sharePromise },
        set: { _ in store.send(.view(.sharePromiseDismissed)) }
      )) { promise in
        ShareSheet(items: [promise.shareText])
      }
      .onChange(of: scenePhase) { _, newPhase in
        store.send(.view(.scenePhaseChanged(newPhase)))
      }
    }
    
    
    @ViewBuilder
    private var groupDetailView: some View {
      VStack(spacing: 0) {
        // Status Filter (고정)
        StatusFilterView(
          selectedFilter: Binding(
            get: { store.selectedFilter },
            set: { store.send(.view(.filterChanged($0))) }
          )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)

        // Promise Timeline (스크롤 가능)
        PromiseTimelineView(
          promisesState: store.promisesState,
          selectedFilter: store.selectedFilter,
          currentUserId: store.currentUser.userId,
          groupMembers: store.currentGroupMembers,
          respondingStates: store.proposalResponding,
          onTap: { promise in store.send(.view(.promiseTapped(promise))) },
          onAccept: { promiseId in store.send(.view(.proposalAccepted(promiseId))) },
          onReject: { promiseId in store.send(.view(.proposalRejected(promiseId))) },
          onDelete: { promiseId in store.send(.view(.promiseDeleted(promiseId))) },
          onChangeResponse: { promiseId, status in
            store.send(.view(.responseChanged(promiseId, status)))
          },
          onShare: { promiseId in store.send(.view(.promiseShared(promiseId))) }
        )
        .refreshable {
          store.send(.view(.refreshTriggered))
        }
      }
    }
    
    @ViewBuilder
    private var groupDetailEmptyView: some View {
      ScrollView {
        VStack(spacing: 0) {
          Spacer()
            .frame(height: 80)
          
          VStack(spacing: 32) {
            // Illustration
            ZStack {
              Circle()
                .fill(
                  LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(width: 120, height: 120)
              
              Image(systemName: "person.3.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                  LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
            }
            
            // Text
            VStack(spacing: 12) {
              Text("그룹이 선택되지 않았어요")
                .font(.title3.bold())
              
              Text("그룹을 만들거나 참여해서\n친구들과 약속을 시작해보세요")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            }
            
            // Action Buttons
            VStack(spacing: 12) {
              GlassActionButton(
                title: "그룹 만들기",
                leadingSystemImage: "plus.circle.fill",
                isPrimary: true,
                action: { store.send(.view(.createGroup))
                }
              )
              
              GlassActionButton(
                title: "초대 코드로 참여하기",
                leadingSystemImage: "link.circle.fill",
                isPrimary: false,
                action: { store.send(.view(.joinGroup)) }
              )
            }
            .padding(.horizontal, 40)
          }
          
          Spacer()
            .frame(height: 80)
        }
      }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
      if let currentGroup = store.currentGroup {
        ToolbarItem(placement: .principal) {
          Text(currentGroup.name)
        }
        
        ToolbarTitleMenu {
          if let allGroups = store.allGroupSummaries, allGroups.isEmpty == false {
            ForEach(allGroups, id: \.id) { group in
              Button {
                store.send(.view(.groupChanged(group)))
              } label: {
                if group.id == currentGroup.id {
                  Label(group.name, systemImage: "checkmark")
                } else {
                  Text(group.name)
                }
              }
              .disabled(group.id == currentGroup.id)
            }
            
            Divider()
          }
          
          Menu("그룹 추가") {
            Button("그룹 만들기", systemImage: "plus") {
              store.send(.view(.createGroup))
            }
            
            Button("초대 코드로 참여하기", systemImage: "link") {
              store.send(.view(.joinGroup))
            }
          }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
          ToolbarButton(
            imageName: "plus",
            action: { store.send(.view(.createNewPromise)) }
          )
        }
        
        ToolbarItem(placement: .topBarTrailing) {
          ToolbarButton(
            imageName: "gearshape",
            action: { store.send(.view(.groupManageTapped)) }
          )
        }
      } else {
        ToolbarItem(placement: .principal) {
          EmptyView()
        }
      }
    }
  }
}

private extension GroupMain.Feature.State {
  
  /// 속한 그룹이 없는 경우
  private var hasNoGroups: Bool {
    allGroupSummaries?.isEmpty == true && currentGroup == nil
  }
  
  /// 활성화된 그룹이 없는 경우
  var shouldShowEmptyGroupView: Bool {
    !promisesState.isLoading && hasNoGroups
  }
  
  /// 특정 약속의 응답 상태 조회
  func respondingState(for promiseId: String) -> GroupMain.RespondingState {
    proposalResponding[promiseId] ?? .idle
  }
}

// MARK: - ShareSheet

import UIKit

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
