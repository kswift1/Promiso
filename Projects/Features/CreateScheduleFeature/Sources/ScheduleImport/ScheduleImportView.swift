import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared
import PhotosUI

// MARK: - Root View

extension ScheduleImport {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack {
        ZStack {
          content
        }
        .auroraBackground()
        .navigationTitle(LocalizedStrings.ScheduleImport.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button {
              store.send(.view(.dismissTapped))
            } label: {
              Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.pmtext.secondary)
            }
            .contentShape(Rectangle())
          }
        }
      }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
      ScrollView {
        VStack(spacing: 16) {
          // Mode Picker
          modePicker

          // Input area
          switch store.inputMode {
          case .text:
            textInputSection
          case .image:
            imageInputSection
          }

          // Error message
          if let error = store.extractionError {
            errorView(message: error)
          }

          // Extract button
          extractButton
        }
        .padding(16)
        .padding(.bottom, 24)
      }
      .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Mode Picker

    @ViewBuilder
    private var modePicker: some View {
      Picker("", selection: Binding(
        get: { store.inputMode },
        set: { store.send(.view(.inputModeChanged($0))) }
      )) {
        Text(LocalizedStrings.ScheduleImport.modeText).tag(Feature.InputMode.text)
        Text(LocalizedStrings.ScheduleImport.modeImage).tag(Feature.InputMode.image)
      }
      .pickerStyle(.segmented)
    }

    // MARK: - Text Input Section

    @ViewBuilder
    private var textInputSection: some View {
      VStack(spacing: 12) {
        // TextEditor
        TextEditor(text: Binding(
          get: { store.inputText },
          set: { store.send(.view(.textChanged($0))) }
        ))
        .font(.system(size: 14))
        .frame(minHeight: 160, maxHeight: 280)
        .scrollContentBackground(.hidden)
        .padding(8)
        .background(Color.pmgray.n100.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topLeading) {
          if store.inputText.isEmpty {
            Text(LocalizedStrings.ScheduleImport.extractionPlaceholder)
              .font(.system(size: 14))
              .foregroundStyle(Color.pmtext.secondary)
              .padding(.horizontal, 12)
              .padding(.vertical, 16)
              .allowsHitTesting(false)
          }
        }
        .adaptiveGlassCard()

        // Paste button + char count
        HStack {
          Button {
            store.send(.view(.pasteFromClipboardTapped))
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "doc.on.clipboard")
                .font(.system(size: 13))
              Text(LocalizedStrings.ScheduleImport.extractionPaste)
                .font(.system(size: 14))
            }
            .foregroundStyle(Color.pmindigo.n500)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.pmindigo.n500.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .buttonStyle(.plain)
          .contentShape(Rectangle())

          Spacer()

          Text("\(store.inputText.count)/2000")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmtext.secondary)
        }
      }
    }

    // MARK: - Image Input Section

    @ViewBuilder
    private var imageInputSection: some View {
      if let imageData = store.selectedImage, let uiImage = UIImage(data: imageData) {
        // 이미지 미리보기 + 오버레이 액션
        ZStack(alignment: .topTrailing) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16))

          // 제거 버튼
          Button {
            store.send(.view(.removeImage))
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(.white)
              .frame(width: 28, height: 28)
              .background(.ultraThinMaterial)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
          .contentShape(Circle())
          .padding(10)
        }
        .adaptiveGlassCard()

        // 다른 사진으로 교체
        PhotosPicker(
          selection: Binding(
            get: { nil as PhotosPickerItem? },
            set: { store.send(.view(.photoSelected($0))) }
          ),
          matching: .images
        ) {
          HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
              .font(.system(size: 13))
            Text("다른 사진 선택")
              .font(.system(size: 14))
          }
          .foregroundStyle(Color.pmindigo.n500)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(Color.pmindigo.n500.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      } else {
        // 사진 선택 placeholder
        PhotosPicker(
          selection: Binding(
            get: { nil as PhotosPickerItem? },
            set: { store.send(.view(.photoSelected($0))) }
          ),
          matching: .images
        ) {
          VStack(spacing: 20) {
            ZStack {
              Circle()
                .fill(Color.pmindigo.n500.opacity(0.1))
                .frame(width: 72, height: 72)

              Image(systemName: "camera.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.pmindigo.n500)
            }

            VStack(spacing: 6) {
              Text(LocalizedStrings.ScheduleImport.selectPhoto)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.pmtext.primary)

              Text(LocalizedStrings.ScheduleImport.selectPhotoHint)
                .font(.system(size: 13))
                .foregroundStyle(Color.pmtext.secondary)
                .multilineTextAlignment(.center)
            }
          }
          .frame(maxWidth: .infinity)
          .frame(minHeight: 240)
          .adaptiveGlassCard()
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .strokeBorder(
                Color.pmindigo.n500.opacity(0.3),
                style: StrokeStyle(lineWidth: 1.5, dash: [8, 5])
              )
          )
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(message: String) -> some View {
      HStack {
        Image(systemName: "exclamationmark.circle")
          .font(.system(size: 13))
        Text(message)
          .font(.system(size: 13))
        Spacer()
        Button {
          store.send(.view(.dismissError))
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 11))
            .padding(8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
      }
      .foregroundStyle(Color.pmerror.n500)
      .padding(8)
      .background(Color.pmerror.n500.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Extract Button

    @ViewBuilder
    private var extractButton: some View {
      Button {
        store.send(.view(.extractTapped))
      } label: {
        HStack(spacing: 6) {
          if store.isExtracting {
            ProgressView()
              .controlSize(.small)
              .tint(.white)
          } else {
            Image(systemName: "sparkles")
              .font(.system(size: 15))
          }
          Text(LocalizedStrings.ScheduleImport.extractionExtract)
            .font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
          store.canExtract
            ? Color.pmindigo.n500
            : Color.pmgray.n400
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      .contentShape(Rectangle())
      .disabled(!store.canExtract)
    }
  }
}

// MARK: - Preview

#Preview {
  ScheduleImport.RootView(
    store: Store(
      initialState: ScheduleImport.Feature.State()
    ) {
      ScheduleImport.Feature()
    } withDependencies: {
      $0.scheduleExtractionClient = .previewValue
    }
  )
}
