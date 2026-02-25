import Clients
import ComposableArchitecture
import PhotosUI
import _PhotosUI_SwiftUI
import ResourceKit
import SwiftUI

// MARK: - Quick Promise Card View

extension QuickPromise {

  public struct CardView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        // 헤더
        headerSection

        // 입력 영역
        inputSection

        // 추출 결과 미리보기
        if let info = store.extractedInfo {
          extractedInfoPreview(info)
        }

        // 에러 메시지
        if let error = store.extractionError {
          errorBanner(error)
        }
      }
      .padding(16)
      .background {
        if #available(iOS 26.0, *) {
          RoundedRectangle(cornerRadius: 20)
            .fill(.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
          RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial)
        }
      }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
      HStack {
        Image(systemName: "sparkles")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.pmindigo.n500)

        Text("빠른 약속 만들기")
          .font(.system(size: 16, weight: .bold))

        Spacer()

        if store.extractedInfo != nil {
          Button {
            store.send(.view(.clearTapped))
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 18))
              .foregroundStyle(.secondary)
          }
        }
      }
    }

    // MARK: - Input Section

    @ViewBuilder
    private var inputSection: some View {
      HStack(spacing: 8) {
        // 텍스트 입력 필드
        TextField("텍스트를 붙여넣거나 입력하세요", text: Binding(
          get: { store.inputText },
          set: { store.send(.view(.textChanged($0))) }
        ), axis: .vertical)
          .font(.system(size: 14))
          .lineLimit(1...4)
          .textFieldStyle(.plain)
          .padding(12)
          .background(Color(.systemGray6).opacity(0.8))
          .clipShape(RoundedRectangle(cornerRadius: 12))

        // 이미지 선택 버튼
        PhotosPicker(
          selection: Binding(
            get: { nil },
            set: { store.send(.view(.photoSelected($0))) }
          ),
          matching: .images,
          photoLibrary: .shared()
        ) {
          Group {
            if store.isExtractingFromImage {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
            } else {
              Image(systemName: "photo.on.rectangle")
                .font(.system(size: 18))
            }
          }
          .frame(width: 44, height: 44)
          .background(Color(.systemGray6).opacity(0.8))
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(store.isExtractingFromImage)

        // 분석 버튼
        Button {
          store.send(.view(.analyzeTextTapped))
        } label: {
          Group {
            if store.isExtracting {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            } else {
              Image(systemName: "text.magnifyingglass")
                .font(.system(size: 18))
            }
          }
          .frame(width: 44, height: 44)
          .background(
            store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              ? Color(.systemGray4)
              : Color.pmindigo.n500
          )
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(
          store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || store.isExtracting
        )
      }
    }

    // MARK: - Extracted Info Preview

    @ViewBuilder
    private func extractedInfoPreview(_ info: PromiseExtractedInfo) -> some View {
      VStack(alignment: .leading, spacing: 8) {
        // 구분선
        Divider()

        // 추출 결과
        HStack(spacing: 6) {
          Image(systemName: info.source == .image ? "photo" : "text.quote")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          Text("추출된 정보")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }

        // 제목
        if let title = info.title {
          infoRow(icon: "pencil", label: "제목", value: title)
        }

        // 날짜/시간
        if let date = info.date {
          infoRow(icon: "calendar", label: "일시", value: Self.dateTimeString(from: date))
        }

        // 장소
        if let location = info.location {
          infoRow(icon: "mappin", label: "장소", value: location)
        }

        // 정보 없음
        if !info.hasAnyInfo {
          HStack(spacing: 6) {
            Image(systemName: "info.circle")
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
            Text("약속 정보를 추출하지 못했습니다. 직접 입력해주세요.")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
          }
        }

        // 약속 만들기 버튼
        Button {
          store.send(.view(.createPromiseTapped))
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 14))
            Text("약속 만들기")
              .font(.system(size: 14, weight: .semibold))
          }
          .frame(maxWidth: .infinity)
          .frame(height: 40)
          .background(Color.pmindigo.n500)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
      }
    }

    // MARK: - Info Row

    @ViewBuilder
    private func infoRow(icon: String, label: String, value: String) -> some View {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 13))
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 20)

        Text(label)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
          .frame(width: 36, alignment: .leading)

        Text(value)
          .font(.system(size: 13))
          .lineLimit(1)
      }
    }

    // MARK: - Helpers

    private static let dateTimeFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "ko_KR")
      formatter.dateFormat = "M월 d일 (E) a h:mm"
      return formatter
    }()

    private static func dateTimeString(from date: Date) -> String {
      dateTimeFormatter.string(from: date)
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 13))
          .foregroundStyle(.orange)

        Text(message)
          .font(.system(size: 13))
          .foregroundStyle(.secondary)

        Spacer()

        Button {
          store.send(.view(.errorDismissed))
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
        }
      }
      .padding(10)
      .background(Color.orange.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}
