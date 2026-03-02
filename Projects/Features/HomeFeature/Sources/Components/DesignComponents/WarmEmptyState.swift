import SwiftUI
import PromisoShared

/// 따뜻한 느낌의 빈 상태 컴포넌트
struct WarmEmptyState: View {
  enum Style {
    case noPromises       // 약속이 전혀 없음
    case noFilterResults  // 필터 결과 없음
    case noGroups         // 그룹이 없음
  }

  let style: Style
  var onPrimaryAction: (() -> Void)? = nil
  var onSecondaryAction: (() -> Void)? = nil

  var body: some View {
    VStack(spacing: 24) {
      // 일러스트/이모지
      illustrationView

      // 텍스트
      VStack(spacing: 8) {
        Text(title)
          .font(.title3)
          .fontWeight(.semibold)
          .foregroundStyle(.primary)

        Text(message)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
      }

      // 액션 버튼
      VStack(spacing: 12) {
        if let primaryAction = onPrimaryAction {
          Button(action: primaryAction) {
            HStack(spacing: 8) {
              Image(systemName: primaryButtonIcon)
              Text(primaryButtonText)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.pmindigo.n500)
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }

        if let secondaryAction = onSecondaryAction {
          Button(action: secondaryAction) {
            Text(secondaryButtonText)
              .font(.subheadline)
              .foregroundStyle(Color.pmindigo.n500)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 60)
    .padding(.horizontal, 32)
  }

  // MARK: - Subviews

  @ViewBuilder
  private var illustrationView: some View {
    ZStack {
      Circle()
        .fill(illustrationBackgroundColor.opacity(0.15))
        .frame(width: 120, height: 120)

      Text(illustrationEmoji)
        .font(.system(size: 56))
    }
  }

  // MARK: - Computed Properties

  private var illustrationEmoji: String {
    switch style {
    case .noPromises: return "🎈"
    case .noFilterResults: return "🔍"
    case .noGroups: return "👋"
    }
  }

  private var illustrationBackgroundColor: Color {
    switch style {
    case .noPromises: return Color.pmindigo.n500
    case .noFilterResults: return Color.pmaurora.purple
    case .noGroups: return Color.green
    }
  }

  private var title: String {
    switch style {
    case .noPromises: return LocalizedStrings.Home.emptyNoPromisesTitle
    case .noFilterResults: return LocalizedStrings.Home.emptyNoFilterTitle
    case .noGroups: return LocalizedStrings.Home.emptyNoGroupsTitle
    }
  }

  private var message: String {
    switch style {
    case .noPromises:
      return LocalizedStrings.Home.emptyNoPromisesMessage
    case .noFilterResults:
      return LocalizedStrings.Home.emptyNoFilterMessage
    case .noGroups:
      return LocalizedStrings.Home.emptyNoGroupsMessage
    }
  }

  private var primaryButtonIcon: String {
    switch style {
    case .noPromises: return "plus.circle.fill"
    case .noFilterResults: return "arrow.counterclockwise"
    case .noGroups: return "person.2.fill"
    }
  }

  private var primaryButtonText: String {
    switch style {
    case .noPromises: return LocalizedStrings.Home.createNewPromise
    case .noFilterResults: return LocalizedStrings.Home.resetFilter
    case .noGroups: return LocalizedStrings.Home.findGroups
    }
  }

  private var secondaryButtonText: String {
    switch style {
    case .noPromises: return LocalizedStrings.Common.laterAction
    case .noFilterResults: return ""
    case .noGroups: return LocalizedStrings.Home.joinWithInviteLink
    }
  }
}

// MARK: - Preview

#Preview("약속 없음") {
  WarmEmptyState(
    style: .noPromises,
    onPrimaryAction: { },
    onSecondaryAction: { }
  )
  .auroraBackground()
}

#Preview("필터 결과 없음") {
  WarmEmptyState(
    style: .noFilterResults,
    onPrimaryAction: { }
  )
  .auroraBackground()
}

#Preview("그룹 없음") {
  WarmEmptyState(
    style: .noGroups,
    onPrimaryAction: { },
    onSecondaryAction: { }
  )
  .auroraBackground()
}
