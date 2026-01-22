import SwiftUI
import ComposableArchitecture

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
          onAddTap: {
            store.send(.view(.addGroupTapped))
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
      .overlay(alignment: .bottomTrailing) {
        createPromiseFAB
      }
    }

    // MARK: - FAB (Floating Action Button)

    private var createPromiseFAB: some View {
      Button {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        store.send(.view(.createNewPromise))
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 56, height: 56)
          .background(Color.pmindigo.n500, in: Circle())
          .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
      }
      .buttonStyle(.plain)
      .padding(.trailing, 20)
      .padding(.bottom, fabBottomPadding)
    }

    private var fabBottomPadding: CGFloat {
      guard store.hasLiveActivity else { return 16 }
      // iOS 26+: BottomAccessory가 얇음
      if #available(iOS 26, *) {
        return 56
      } else {
        return 80
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
        // 응답 필요 섹션
        if !store.needResponsePromises.isEmpty {
          PromiseSectionView(
            title: "응답 필요",
            icon: "envelope.badge",
            promises: store.needResponsePromises,
            maxDisplay: 3,
            currentUserId: store.currentUser.userId,
            groupMembers: store.currentGroupMembers,
            respondingStates: store.proposalResponding,
            onPromiseTap: { promise in
              store.send(.view(.promiseTapped(promise)))
            },
            onMoreTap: store.needResponsePromises.count > 3 ? {
              store.send(.view(.moreNeedResponseTapped))
            } : nil,
            onAccept: { promise in
              store.send(.view(.proposalAccepted(promise.id)))
            },
            onReject: { promise in
              store.send(.view(.proposalRejected(promise.id)))
            },
            onChangeResponse: { promise, status in
              store.send(.view(.responseChanged(promise.id, status)))
            },
            onEdit: { promise in
              store.send(.view(.promiseEditTapped(promise)))
            },
            onDelete: { promise in
              store.send(.view(.promiseDeleteRequested(promise.id)))
            },
            onShare: { promise in
              store.send(.view(.promiseShared(promise.id)))
            }
          )
        }

        // 확정 약속 섹션
        if !store.confirmedPromises.isEmpty {
          PromiseSectionView(
            title: "다가오는 확정 약속",
            icon: "checkmark.circle",
            promises: store.confirmedPromises,
            maxDisplay: 2,
            currentUserId: store.currentUser.userId,
            groupMembers: store.currentGroupMembers,
            respondingStates: store.proposalResponding,
            onPromiseTap: { promise in
              store.send(.view(.promiseTapped(promise)))
            },
            onMoreTap: store.confirmedPromises.count > 2 ? {
              store.send(.view(.moreConfirmedTapped))
            } : nil,
            onAccept: nil,
            onReject: nil,
            onChangeResponse: nil,
            onEdit: { promise in
              store.send(.view(.promiseEditTapped(promise)))
            },
            onDelete: { promise in
              store.send(.view(.promiseDeleteRequested(promise.id)))
            },
            onShare: { promise in
              store.send(.view(.promiseShared(promise.id)))
            }
          )
        }

        // 빈 상태
        if store.needResponsePromises.isEmpty && store.confirmedPromises.isEmpty {
          emptyPromiseView
        }

        Divider()
          .padding(.vertical, 16)

        // 하단 메뉴
        bottomMenuSection
      }
    }

    @ViewBuilder
    private var emptyPromiseView: some View {
      VStack(spacing: 16) {
        Image(systemName: "calendar.badge.plus")
          .font(.system(size: 48))
          .foregroundStyle(.secondary)

        Text("아직 약속이 없어요")
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(.secondary)

        Button {
          store.send(.view(.createNewPromise))
        } label: {
          HStack {
            Image(systemName: "plus")
            Text("약속 만들기")
          }
          .font(.system(size: 15, weight: .semibold))
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
          .background(Color.pmindigo.n500)
          .foregroundStyle(.white)
          .clipShape(Capsule())
        }
        .buttonStyle(.hapticBounce)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 40)
    }

    @ViewBuilder
    private var bottomMenuSection: some View {
      VStack(spacing: 0) {
        // 모든 약속 보기
        MenuRowButton(
          title: "모든 약속 보기",
          icon: "list.bullet",
          action: { store.send(.view(.allPromisesTapped)) }
        )

        Divider()
          .padding(.leading, 52)

        // 그룹 설정
        MenuRowButton(
          title: "그룹 설정",
          icon: "gearshape",
          action: { store.send(.view(.groupSettingsTapped)) }
        )
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 24)
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

// MARK: - MenuRowButton

private struct MenuRowButton: View {
  let title: String
  let icon: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 18))
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 24)

        Text(title)
          .font(.system(size: 16))
          .foregroundStyle(.primary)

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.vertical, 14)
    }
    .buttonStyle(.scale)
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
