import SwiftUI

// MARK: - Sliding Segment Control

/// iOS Mail 스타일의 슬라이딩 세그먼트 컨트롤
///
/// 버튼들은 고정되고, 선택 시 배경 캡슐만 슬라이딩 애니메이션으로 이동합니다.
///
/// ```swift
/// @State private var selected = "전체"
/// let options = ["전체", "응답 필요", "확정"]
///
/// SlidingSegmentControl(
///   options: options,
///   selection: $selected
/// )
/// ```
public struct SlidingSegmentControl<Option: Hashable>: View {
  private let options: [Option]
  @Binding private var selection: Option
  private let titleProvider: (Option) -> String

  @Namespace private var animation

  public init(
    options: [Option],
    selection: Binding<Option>,
    title: @escaping (Option) -> String
  ) {
    self.options = options
    self._selection = selection
    self.titleProvider = title
  }

  public var body: some View {
    HStack(spacing: 4) {
      ForEach(options, id: \.self) { option in
        segmentButton(for: option)
      }
    }
    .padding(4)
    .background(Color(uiColor: .systemGray6))
    .clipShape(Capsule())
  }

  @ViewBuilder
  private func segmentButton(for option: Option) -> some View {
    let isSelected = selection == option

    Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        selection = option
      }
    } label: {
      Text(titleProvider(option))
        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
        .foregroundStyle(isSelected ? .primary : .secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
          if isSelected {
            Capsule()
              .fill(Color(uiColor: .systemBackground))
              .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
              .matchedGeometryEffect(id: "segment", in: animation)
          }
        }
    }
    .buttonStyle(.plain)
  }
}

// MARK: - String Convenience Initializer

public extension SlidingSegmentControl where Option == String {
  init(
    options: [String],
    selection: Binding<String>
  ) {
    self.init(options: options, selection: selection) { $0 }
  }
}

// MARK: - RawRepresentable Convenience Initializer

public extension SlidingSegmentControl where Option: RawRepresentable, Option.RawValue == String {
  init(
    options: [Option],
    selection: Binding<Option>
  ) {
    self.init(options: options, selection: selection) { $0.rawValue }
  }
}

// MARK: - Previews

#Preview("기본") {
  struct PreviewWrapper: View {
    @State private var selection = "전체"

    var body: some View {
      VStack(spacing: 24) {
        SlidingSegmentControl(
          options: ["전체", "응답 필요", "확정"],
          selection: $selection
        )
        .padding(.horizontal)

        Text("선택: \(selection)")
          .foregroundStyle(.secondary)
      }
    }
  }

  return PreviewWrapper()
}

#Preview("2개 옵션") {
  struct PreviewWrapper: View {
    @State private var selection = "읽지 않음"

    var body: some View {
      VStack(spacing: 24) {
        SlidingSegmentControl(
          options: ["전체", "읽지 않음"],
          selection: $selection
        )
        .padding(.horizontal)

        Text("선택: \(selection)")
          .foregroundStyle(.secondary)
      }
    }
  }

  return PreviewWrapper()
}

#Preview("4개 옵션") {
  struct PreviewWrapper: View {
    @State private var selection = "전체"

    var body: some View {
      VStack(spacing: 24) {
        SlidingSegmentControl(
          options: ["전체", "응답 필요", "응답 완료", "확정"],
          selection: $selection
        )
        .padding(.horizontal)

        Text("선택: \(selection)")
          .foregroundStyle(.secondary)
      }
    }
  }

  return PreviewWrapper()
}

#Preview("다크모드") {
  struct PreviewWrapper: View {
    @State private var selection = "전체"

    var body: some View {
      VStack(spacing: 24) {
        SlidingSegmentControl(
          options: ["전체", "응답 필요", "확정"],
          selection: $selection
        )
        .padding(.horizontal)

        Text("선택: \(selection)")
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 40)
      .frame(maxWidth: .infinity)
      .background(Color(uiColor: .systemBackground))
    }
  }

  return PreviewWrapper()
    .preferredColorScheme(.dark)
}

#Preview("리스트 컨텍스트") {
  struct PreviewWrapper: View {
    @State private var selection = "전체"

    var body: some View {
      VStack(spacing: 0) {
        // 헤더
        VStack(spacing: 12) {
          Text("일정")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)

          SlidingSegmentControl(
            options: ["전체", "응답 필요", "확정"],
            selection: $selection
          )
        }
        .padding()
        .background(Color(uiColor: .systemBackground))

        Divider()

        // 리스트
        List {
          ForEach(0..<10, id: \.self) { index in
            HStack {
              Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)

              VStack(alignment: .leading) {
                Text("일정 \(index + 1)")
                  .font(.headline)
                Text("설명 텍스트")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 4)
          }
        }
        .listStyle(.plain)
      }
    }
  }

  return PreviewWrapper()
}

#Preview("Enum 사용") {
  enum Filter: String, CaseIterable {
    case all = "전체"
    case needResponse = "응답 필요"
    case confirmed = "확정"
  }

  struct PreviewWrapper: View {
    @State private var selection: Filter = .all

    var body: some View {
      VStack(spacing: 24) {
        SlidingSegmentControl(
          options: Filter.allCases,
          selection: $selection
        )
        .padding(.horizontal)

        Text("선택: \(selection.rawValue)")
          .foregroundStyle(.secondary)
      }
    }
  }

  return PreviewWrapper()
}
