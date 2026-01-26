import SwiftUI
import PromisoShared

/// Smart Pills 필터 바 - Pill 스타일 상태 필터
struct SmartPillsFilter: View {
  @Binding var selection: StatusFilter
  let counts: [StatusFilter: Int]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(StatusFilter.allCases, id: \.self) { filter in
          PillButton(
            title: filter.rawValue,
            count: counts[filter] ?? 0,
            isSelected: selection == filter,
            action: {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection = filter
              }
            }
          )
        }
      }
      .padding(.horizontal, 16)
    }
  }
}

/// 개별 Pill 버튼
private struct PillButton: View {
  let title: String
  let count: Int
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Text(title)
          .font(.subheadline)
          .fontWeight(isSelected ? .semibold : .regular)

        if count > 0 {
          Text("\(count)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(isSelected ? Color.pmindigo.n500 : .white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
              isSelected
                ? Color.white
                : Color.pmindigo.n500.opacity(0.8)
            )
            .clipShape(Capsule())
        }
      }
      .foregroundStyle(isSelected ? .white : .primary)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(
        isSelected
          ? Color.pmindigo.n500
          : Color(.systemBackground).opacity(0.6)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(
            isSelected
              ? Color.clear
              : Color(.separator).opacity(0.5),
            lineWidth: 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: 20))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Preview

#Preview("필터 선택") {
  struct PreviewWrapper: View {
    @State private var selection: StatusFilter = .all

    var body: some View {
      VStack(spacing: 20) {
        SmartPillsFilter(
          selection: $selection,
          counts: [
            .all: 8,
            .needResponse: 2,
            .confirmed: 4,
            .inProgress: 2
          ]
        )

        Text("선택됨: \(selection.rawValue)")
          .font(.headline)
      }
      .padding(.vertical)
      .auroraBackground()
    }
  }

  return PreviewWrapper()
}

#Preview("응답 필요 선택") {
  struct PreviewWrapper: View {
    @State private var selection: StatusFilter = .needResponse

    var body: some View {
      SmartPillsFilter(
        selection: $selection,
        counts: [
          .all: 12,
          .needResponse: 5,
          .confirmed: 6,
          .inProgress: 1
        ]
      )
      .padding(.vertical)
      .auroraBackground()
    }
  }

  return PreviewWrapper()
}
