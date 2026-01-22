import SwiftUI
import ComposableArchitecture
import PromisoShared

extension GroupMain {
  public struct RootView: View {
    @Bindable private var store: StoreOf<GroupMain.Feature>

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
          case .groupSettings(let groupSettingsStore):
            GroupSettings.View(store: groupSettingsStore)
          case .groupPromiseList(let groupPromiseListStore):
            GroupPromiseList.View(store: groupPromiseListStore)
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
      .toolbarVisibility(.hidden, for: .navigationBar)
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
      .sheet(
        store: store.scope(state: \.$editPromise, action: \.editPromise)
      ) { editStore in
        EditPromise.RootView(store: editStore)
      }
      .alert(store: store.scope(state: \.$deleteAlert, action: \.deleteAlert))
      .confirmationDialog(
        store: store.scope(state: \.$groupActionSheet, action: \.groupActionSheet)
      )
    }


    // MARK: - New Group Detail View (섹션 기반)

    @ViewBuilder
    private var groupDetailView: some View {
      // 약속 컨텐츠 (스크롤 + 리프레시)
      ScrollView {
        // 그룹 가로 바 (상단 고정)
        GroupHorizontalBar(
          groups: store.groupBarItems,
          onGroupTap: { groupId in
            store.send(.view(.groupTapped(groupId)))
          },
          onCreateGroup: {
            store.send(.view(.createGroup))
          },
          onJoinGroup: {
            store.send(.view(.joinGroup))
          }
        )
        
        Divider()
        
        VStack(spacing: 0) {
          // 로딩 상태
          if store.promisesState.isLoading {
            loadingView
          } else if let error = store.promisesState.error {
            errorView(error: error)
          } else {
            // 컨텐츠
            contentSections
          }
        }
      }
      .refreshable {
        store.send(.view(.refreshTriggered))
      }
      .overlay {
        morphingFABMenu
      }
    }

    // MARK: - Morphing FAB Menu

    private var morphingFABMenu: some View {
      MorphingFABMenu(
        items: [
          FABMenuItem(
            title: "약속 생성",
            icon: "calendar.badge.plus",
            tintColor: .pmindigo.n500
          ) {
            store.send(.view(.createNewPromise))
          },
          FABMenuItem(
            title: "그룹 설정",
            icon: "gearshape",
            tintColor: .pmindigo.n500
          ) {
            store.send(.view(.groupSettingsTapped))
          }
        ],
        bottomPadding: fabBottomPadding
      )
    }

    private var fabBottomPadding: CGFloat {
      guard store.hasLiveActivity else { return 16 }
      // iOS 26+: BottomAccessory가 얇음
      if #available(iOS 26, *) {
        return 20
      } else {
        return 85
      }
    }

    @ViewBuilder
    private var loadingView: some View {
      VStack(spacing: 16) {
        ProgressView()
        Text("약속을 불러오는 중...")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 60)
    }

    @ViewBuilder
    private func errorView(error: Error) -> some View {
      VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 40))
          .foregroundStyle(.secondary)

        Text(error.localizedDescription)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        Button("다시 시도") {
          store.send(.view(.refreshTriggered))
        }
        .buttonStyle(.bordered)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 60)
      .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var contentSections: some View {
      VStack(spacing: 0) {
        // 필터 세그먼트
        filterSegment
          .padding(.vertical, 8)

        // 필터된 약속 리스트
        if store.filteredPromises.isEmpty {
          emptyFilteredView
        } else {
          promiseListView
        }
      }
    }

    @ViewBuilder
    private var filterSegment: some View {
      CategoryFilterBar(
        selection: Binding(
          get: { store.selectedFilter },
          set: { store.send(.view(.filterChanged($0))) }
        )
      )
    }

    @ViewBuilder
    private var promiseListView: some View {
      LazyVStack(spacing: 12) {
        ForEach(store.filteredPromises, id: \.id) { promise in
          promiseCardView(for: promise)
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 100) // FAB 공간 확보
    }

    @ViewBuilder
    private func promiseCardView(for promise: PromiseModel) -> some View {
      let promiseId = promise.id
      PromiseCard(
        promise: promise,
        currentUserId: store.currentUser.userId,
        groupMembers: store.currentGroupMembers,
        respondingState: store.proposalResponding[promiseId] ?? .idle,
        onTap: {
          store.send(.view(.promiseTapped(promise)))
        },
        onAccept: {
          store.send(.view(.proposalAccepted(promiseId)))
        },
        onReject: {
          store.send(.view(.proposalRejected(promiseId)))
        },
        onEdit: {
          store.send(.view(.promiseEditTapped(promise)))
        },
        onDelete: {
          store.send(.view(.promiseDeleteRequested(promiseId)))
        },
        onChangeResponse: { status in
          store.send(.view(.responseChanged(promiseId, status)))
        },
        onShare: {
          store.send(.view(.promiseShared(promiseId)))
        }
      )
    }

    @ViewBuilder
    private var emptyFilteredView: some View {
      VStack(spacing: 16) {
        Image(systemName: emptyFilterIcon)
          .font(.system(size: 48))
          .foregroundStyle(.secondary)

        Text(emptyFilterMessage)
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 60)
    }

    private var emptyFilterIcon: String {
      switch store.selectedFilter {
      case .needResponse: return "envelope.badge"
      case .responded: return "clock.badge.checkmark"
      case .confirmed: return "checkmark.circle"
      case .all: return "calendar.badge.plus"
      case .past: return "clock.arrow.circlepath"
      }
    }

    private var emptyFilterMessage: String {
      switch store.selectedFilter {
      case .needResponse: return "응답이 필요한 약속이 없어요"
      case .responded: return "응답 완료된 약속이 없어요"
      case .confirmed: return "확정된 약속이 없어요"
      case .all: return "아직 약속이 없어요"
      case .past: return "지난 약속이 없어요"
      }
    }


    // MARK: - Empty Group View

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

  }
}

// MARK: - State Extensions

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
