import Clients
import ComposableArchitecture
import Nuke
import PromisoShared

// MARK: - New UI Action Helpers

func handleMoreNeedResponseTapped(
  _ state: inout GroupMain.Feature.State
) -> Effect<GroupMain.Feature.Action> {
  guard let currentGroup = state.currentGroup else { return .none }
  state.path.append(.groupPromiseList(.init(
    group: currentGroup,
    promises: state.allPromises,
    currentUserId: state.currentUser.userId,
    groupMembers: state.currentGroupMembers,
    initialFilter: .needResponse
  )))
  return .none
}

func handleMoreConfirmedTapped(
  _ state: inout GroupMain.Feature.State
) -> Effect<GroupMain.Feature.Action> {
  guard let currentGroup = state.currentGroup else { return .none }
  state.path.append(.groupPromiseList(.init(
    group: currentGroup,
    promises: state.allPromises,
    currentUserId: state.currentUser.userId,
    groupMembers: state.currentGroupMembers,
    initialFilter: .confirmed
  )))
  return .none
}

func handleAllPromisesTapped(
  _ state: inout GroupMain.Feature.State
) -> Effect<GroupMain.Feature.Action> {
  guard let currentGroup = state.currentGroup else { return .none }
  state.path.append(.groupPromiseList(.init(
    group: currentGroup,
    promises: state.allPromises,
    currentUserId: state.currentUser.userId,
    groupMembers: state.currentGroupMembers,
    initialFilter: .all
  )))
  return .none
}

func handleGroupSettingsTapped(
  _ state: inout GroupMain.Feature.State
) -> Effect<GroupMain.Feature.Action> {
  guard let currentGroup = state.currentGroup else { return .none }
  let summary = state.allGroupSummaries?.first { $0.id == currentGroup.id }
  let upcomingPromises = state.allPromises.filter { $0.isUpcoming }
  state.path.append(.groupSettings(.init(
    group: currentGroup,
    summary: summary,
    currentUserId: state.currentUser.userId,
    isPro: state.isPro,
    preloadedMembers: state.currentGroupMembers,
    upcomingPromises: upcomingPromises
  )))
  return .none
}

// MARK: - Deeplink Helpers

extension GroupMain.Feature.State {
  /// 딥링크 처리 시 다른 그룹으로 이동하는 경우에만 path 초기화
  mutating func clearPathIfGroupChanged(targetGroupId: String) {
    if currentGroup?.id != targetGroupId {
      path.removeAll()
    }
  }
}

// MARK: - LiveActivity Profile Image Caching

/// LiveActivity용 프로필 이미지 사전 캐싱
///
/// APNs 원격 LiveActivity 시작 시 앱 코드가 실행되지 않으므로,
/// 멤버 로드 시점에 미리 App Group에 캐싱합니다.
/// - 이미 캐시된 이미지는 스킵
/// - 다운로드 실패 시 Widget에서 이모지로 fallback
func cacheProfileImagesForLiveActivity(members: [UserPublicModel]) async {
  AppLogger.liveActivity.debug("프로필 이미지 캐싱 시작: \(members.count)명")

  await withTaskGroup(of: Void.self) { group in
    for member in members {
      group.addTask {
        guard let urlString = member.profileImageUrl,
              let url = URL(string: urlString) else {
          AppLogger.liveActivity.debug("프로필 URL 없음: \(member.userId)")
          return
        }

        // 매번 저장 (덮어쓰기) - 프로필 변경 즉시 반영
        // Nuke 캐시로 네트워크 비용 없음, TaskGroup이 병렬 처리
        do {
          let image = try await ImagePipeline.shared.image(for: url)
          LiveActivityImageStore.saveImage(image, userId: member.userId)
        } catch {
          AppLogger.liveActivity.error("다운로드 실패: \(member.userId), \(error)")
        }
      }
    }
  }
}
