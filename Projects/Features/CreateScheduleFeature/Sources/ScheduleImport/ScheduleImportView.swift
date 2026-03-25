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
        // Image preview
        VStack(spacing: 8) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 280)
            .clipShape(RoundedRectangle(cornerRadius: 12))

          Button {
            store.send(.view(.removeImage))
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "xmark.circle")
                .font(.system(size: 13))
              Text(LocalizedStrings.ScheduleImport.removeImage)
                .font(.system(size: 14))
            }
            .foregroundStyle(Color.pmerror.n500)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.pmerror.n500.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .buttonStyle(.plain)
          .contentShape(Rectangle())
        }
      } else {
        // Photo picker placeholder
        PhotosPicker(
          selection: Binding(
            get: { nil as PhotosPickerItem? },
            set: { store.send(.view(.photoSelected($0))) }
          ),
          matching: .images
        ) {
          VStack(spacing: 16) {
            Image(systemName: "photo.badge.plus")
              .font(.system(size: 48))
              .foregroundStyle(Color.pmindigo.n500)

            VStack(spacing: 4) {
              Text(LocalizedStrings.ScheduleImport.selectPhoto)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.pmtext.primary)

              Text(LocalizedStrings.ScheduleImport.selectPhotoHint)
                .font(.system(size: 13))
                .foregroundStyle(Color.pmtext.secondary)
                .multilineTextAlignment(.center)
            }
          }
          .frame(maxWidth: .infinity)
          .frame(minHeight: 200)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .strokeBorder(
                Color.pmindigo.n500.opacity(0.4),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
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
