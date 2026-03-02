import PromisoShared
import SwiftUI

// MARK: - Menu Item Model

struct FABMenuItem: Identifiable {
  let id = UUID()
  let title: String
  let icon: String
  let tintColor: Color
  let action: () -> Void

  init(title: String, icon: String, tintColor: Color = .primary, action: @escaping () -> Void) {
    self.title = title
    self.icon = icon
    self.tintColor = tintColor
    self.action = action
  }
}

// MARK: - Morphing FAB Menu

/// 그룹 탭용 FAB 메뉴
/// GlassExpandableMenu를 사용하여 morphing 효과 구현
struct MorphingFABMenu: View {
  let items: [FABMenuItem]
  let bottomPadding: CGFloat
  let labelSize: CGSize
  let cornerRadius: CGFloat
  let isVisible: Bool

  @State private var progress: CGFloat = 0

  private let animationType: GlassMenuAnimationType = .bouncy

  init(
    items: [FABMenuItem],
    bottomPadding: CGFloat = 16,
    labelSize: CGSize = .init(width: 56, height: 56),
    cornerRadius: CGFloat = 28,
    isVisible: Bool = true
  ) {
    self.items = items
    self.bottomPadding = bottomPadding
    self.labelSize = labelSize
    self.cornerRadius = cornerRadius
    self.isVisible = isVisible
  }

  private var isExpanded: Bool {
    progress > 0
  }

  var body: some View {
    ZStack {
      // Dimmed background - 탭하거나 스크롤하면 닫힘
      if isExpanded {
        Color.black.opacity(0.3 * progress)
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {
            collapse()
          }
          .gesture(
            DragGesture(minimumDistance: 5)
              .onChanged { _ in
                collapseWithoutHaptic()
              }
          )
          .allowsHitTesting(isExpanded)
      }

      // Menu
      GlassExpandableMenu(
        alignment: .bottomTrailing,
        progress: progress,
        labelSize: labelSize,
        cornerRadius: cornerRadius,
        labelBackgroundColor: .pmindigo.n500
      ) {
        expandedContent
      } label: {
        collapsedLabel
          .contentShape(Circle())
          .onTapGesture {
            expand()
          }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      .padding(.trailing, 20)
      .padding(.bottom, bottomPadding)
    }
    .opacity(isVisible ? 1 : 0)
    .allowsHitTesting(isVisible)
  }

  // MARK: - Collapsed Label (FAB Button)

  private var collapsedLabel: some View {
    Image(systemName: "plus")
      .font(.system(size: 24, weight: .semibold))
      .foregroundStyle(iOS26Available ? Color.pmindigo.n500 : .white)
      .frame(width: labelSize.width, height: labelSize.height)
  }

  // MARK: - Expanded Content

  private var expandedContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        Button {
          selectItem(item)
        } label: {
          HStack(spacing: 14) {
            Image(systemName: item.icon)
              .font(.system(size: 18, weight: .medium))
              .foregroundStyle(item.tintColor)
              .frame(width: 40, height: 40)
              .background(Color.primary.opacity(0.08), in: Circle())

            Text(item.title)
              .font(.system(size: 16, weight: .medium))
              .foregroundStyle(.primary)

            Spacer(minLength: 20)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if index < items.count - 1 {
          Divider()
            .padding(.leading, 66)
        }
      }
    }
    .padding(.vertical, 8)
  }

  // MARK: - Actions

  private func expand() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    withAnimation(animationType.animation) {
      progress = 1
    }
  }

  private func collapse() {
    guard isExpanded else { return }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(animationType.animation) {
      progress = 0
    }
  }

  private func collapseWithoutHaptic() {
    guard isExpanded else { return }
    withAnimation(animationType.animation) {
      progress = 0
    }
  }

  private func selectItem(_ item: FABMenuItem) {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(animationType.animation) {
      progress = 0
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      item.action()
    }
  }

  private var iOS26Available: Bool {
    if #available(iOS 26, *) { return true }
    return false
  }
}

// MARK: - Preview

#Preview("MorphingFABMenu") {
  ZStack {
    LinearGradient(
      colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()

    VStack {
      Text("Sample Content")
        .font(.largeTitle)
      Spacer()
    }
    .padding()

    MorphingFABMenu(
      items: [
        FABMenuItem(title: "새 약속", icon: "calendar.badge.plus", tintColor: .pmindigo.n500) {
        },
        FABMenuItem(title: "그룹 만들기", icon: "person.3.fill", tintColor: .pmindigo.n500) {
        },
        FABMenuItem(title: "그룹 참여", icon: "link", tintColor: .pmindigo.n500) {
        }
      ],
      bottomPadding: 20
    )
  }
}
