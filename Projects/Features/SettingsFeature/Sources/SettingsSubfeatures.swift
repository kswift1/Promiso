import Clients
import ComposableArchitecture
import PromisoShared
import SwiftUI

// MARK: - DateTimeSettings Namespace

public enum DateTimeSettings {}

// MARK: - DateTimeSettings Feature

extension DateTimeSettings {

  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      @Shared(.appStorage(AppConstants.UserDefaults.use24HourFormat)) public var use24HourFormat: Bool = false
      /// 선택된 값 (임시)
      var selectedValue: Bool = false

      public init() {}
    }

    public enum Action: Equatable, Sendable {
      case view(View)
    }

    public enum View: Equatable, Sendable {
      case onAppear
      case formatSelected(Bool)
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            state.selectedValue = state.use24HourFormat
            return .none

          case .formatSelected(let value):
            state.selectedValue = value
            state.$use24HourFormat.withLock { $0 = value }
            LocalizedDateFormatters.use24HourFormat = value
            return .run { _ in
              await hapticFeedback.selection()
            }
          }
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          timeFormatSection
          exampleCardSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.dateTimeDisplay)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private var timeFormatSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.timeFormatSection)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          formatRow(is24Hour: false, title: LocalizedStrings.SettingsStrings.timeFormat12Hour, description: LocalizedStrings.SettingsStrings.timeFormat12HourExample)
          Divider()
            .padding(.leading, 48)
          formatRow(is24Hour: true, title: LocalizedStrings.SettingsStrings.timeFormat24Hour, description: LocalizedStrings.SettingsStrings.timeFormat24HourExample)
        }
        .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.timeFormatHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    private func formatRow(is24Hour: Bool, title: String, description: String) -> some View {
      Button {
        store.send(.view(.formatSelected(is24Hour)))
      } label: {
        HStack(spacing: 12) {
          Image(systemName: "clock")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 20)

          VStack(alignment: .leading, spacing: 2) {
            Text(title)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Text(description)
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()

          if store.selectedValue == is24Hour {
            Image(systemName: "checkmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color.pmindigo.n500)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }

    private var exampleCardSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.preview)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        ExamplePromiseCard(use24Hour: store.selectedValue)

        Text(LocalizedStrings.SettingsStrings.previewHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }
  }

  // MARK: - Example Promise Card

  private struct ExamplePromiseCard: View {
    let use24Hour: Bool

    private var timeString: String {
      if use24Hour {
        return LocalizedStrings.SettingsStrings.exampleTime24
      } else {
        return LocalizedStrings.SettingsStrings.exampleTime12
      }
    }

    private var dateString: String {
      LocalizedStrings.SettingsStrings.exampleDate
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 14) {
        // Main Content
        HStack(alignment: .top, spacing: 12) {
          Text("🍽️")
            .font(.system(size: 44))

          VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStrings.SettingsStrings.exampleTitle)
              .font(.system(size: 19, weight: .bold))
              .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 6) {
              // Date & Time
              HStack(spacing: 4) {
                Text("⏰")
                  .font(.system(size: 14))
                Text("\(dateString) \(timeString)")
                  .font(.system(size: 14, weight: .medium))
              }
              .foregroundColor(.primary)

              // Location
              HStack(spacing: 4) {
                Text("📍")
                  .font(.system(size: 14))
                Text(LocalizedStrings.SettingsStrings.exampleLocation)
                  .font(.system(size: 14, weight: .medium))
              }
              .foregroundColor(.primary)
            }
          }

          Spacer()
        }
      }
      .padding(16)
      .adaptiveGlassCard()
    }
  }
}

// MARK: - ThemeSettings Namespace

public enum ThemeSettings {}

// MARK: - ThemeSettings Feature

extension ThemeSettings {

  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      @Shared(.appStorage(AppConstants.UserDefaults.preferredThemeMode)) public var themeMode: String = AppConstants.ThemeMode.system.rawValue

      public init() {}
    }

    public enum Action: Equatable, Sendable {
      case view(View)
    }

    public enum View: Equatable, Sendable {
      case onAppear
      case themeModeChanged(AppConstants.ThemeMode)
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .none

          case .themeModeChanged(let mode):
            guard mode.rawValue != state.themeMode else { return .none }
            state.$themeMode.withLock { $0 = mode.rawValue }
            return .run { _ in
              await hapticFeedback.selection()
            }
          }
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    private var currentMode: AppConstants.ThemeMode {
      AppConstants.ThemeMode(rawValue: store.themeMode) ?? .system
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          themeModeSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.themeModeNavigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private var themeModeSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.themeModeSectionTitle)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          ForEach(AppConstants.ThemeMode.allCases, id: \.rawValue) { mode in
            themeModeRow(mode: mode)
            if mode != AppConstants.ThemeMode.allCases.last {
              Divider()
                .padding(.leading, 48)
            }
          }
        }
        .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.themeModeSectionHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    private func themeModeRow(mode: AppConstants.ThemeMode) -> some View {
      Button {
        store.send(.view(.themeModeChanged(mode)))
      } label: {
        HStack(spacing: 12) {
          Image(systemName: iconName(for: mode))
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 20)

          VStack(alignment: .leading, spacing: 2) {
            Text(mode.displayName)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Text(description(for: mode))
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()

          if currentMode == mode {
            Image(systemName: "checkmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color.pmindigo.n500)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }

    private func iconName(for mode: AppConstants.ThemeMode) -> String {
      switch mode {
      case .system: return "iphone"
      case .light: return "sun.max.fill"
      case .dark: return "moon.fill"
      }
    }

    private func description(for mode: AppConstants.ThemeMode) -> String {
      switch mode {
      case .system: return LocalizedStrings.SettingsStrings.themeModeSystemDescription
      case .light: return LocalizedStrings.SettingsStrings.themeModeLightDescription
      case .dark: return LocalizedStrings.SettingsStrings.themeModeDarkDescription
      }
    }
  }
}

// MARK: - LanguageSettings Namespace

public enum LanguageSettings {}

// MARK: - LanguageSettings Feature

extension LanguageSettings {

  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      @Shared(.appStorage(AppConstants.UserDefaults.preferredLanguage)) public var preferredLanguage: String = ""

      public init() {}
    }

    public enum Action: Equatable, Sendable {
      case view(View)
    }

    public enum View: Equatable, Sendable {
      case onAppear
      case languageChanged(AppLanguage)
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .none

          case .languageChanged(let language):
            guard language.rawValue != state.preferredLanguage else { return .none }
            state.$preferredLanguage.withLock { $0 = language.rawValue }
            LocalizedStrings.configure()
            LocalizedDateFormatters.updateLocale()
            return .run { _ in
              await hapticFeedback.selection()
            }
          }
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    private var currentLanguage: AppLanguage {
      if store.preferredLanguage.isEmpty {
        // 시스템 기본 - 현재 시스템 언어 감지
        let systemLang = Locale.current.language.languageCode?.identifier ?? "ko"
        return AppLanguage(rawValue: systemLang) ?? .korean
      }
      return AppLanguage(rawValue: store.preferredLanguage) ?? .korean
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          languageSection

          systemLanguageHint
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.language)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private var languageSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.languageSectionTitle)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          ForEach(AppLanguage.allCases, id: \.rawValue) { language in
            languageRow(language: language)
            if language != AppLanguage.allCases.last {
              Divider()
                .padding(.leading, 48)
            }
          }
        }
        .adaptiveGlassCard()
      }
    }

    private var systemLanguageHint: some View {
      Text(LocalizedStrings.SettingsStrings.languageHint)
        .font(.system(size: 12))
        .foregroundStyle(Color.pmtext.secondary)
        .padding(.horizontal, 4)
    }

    private func languageRow(language: AppLanguage) -> some View {
      Button {
        store.send(.view(.languageChanged(language)))
      } label: {
        HStack(spacing: 12) {
          Text(language.icon)
            .font(.system(size: 20))
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 2) {
            Text(language.displayName)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)
          }

          Spacer()

          if currentLanguage == language {
            Image(systemName: "checkmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color.pmindigo.n500)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - PromiseTabModeSettings Namespace

public enum PromiseTabModeSettings {}

// MARK: - PromiseTabModeSettings Feature

extension PromiseTabModeSettings {

  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      @Shared(.appStorage(AppConstants.UserDefaults.defaultPromiseTabMode)) public var defaultPromiseTabMode: String = "group"

      public init() {}
    }

    public enum Action: Equatable, Sendable {
      case view(View)
    }

    public enum View: Equatable, Sendable {
      case onAppear
      case tabModeChanged(String)
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .none

          case .tabModeChanged(let mode):
            state.$defaultPromiseTabMode.withLock { $0 = mode }
            return .run { _ in
              await hapticFeedback.selection()
            }
          }
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          tabModeSection
          tabBarPreviewSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.promiseTabDefaultMode)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private var tabModeSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.promiseTabModeDefault)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          tabModeRow(mode: "group", icon: "person.3.fill", title: LocalizedStrings.SettingsStrings.promiseTabModeGroup, description: LocalizedStrings.SettingsStrings.promiseTabModeGroupDescription)
          Divider()
            .padding(.leading, 48)
          tabModeRow(mode: "own", icon: "person.fill", title: LocalizedStrings.SettingsStrings.promiseTabModeOwn, description: LocalizedStrings.SettingsStrings.promiseTabModeOwnDescription)
        }
        .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.promiseTabModeHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    private func tabModeRow(mode: String, icon: String, title: String, description: String) -> some View {
      Button {
        store.send(.view(.tabModeChanged(mode)))
      } label: {
        HStack(spacing: 12) {
          Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 20)

          VStack(alignment: .leading, spacing: 2) {
            Text(title)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Text(description)
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()

          if store.defaultPromiseTabMode == mode {
            Image(systemName: "checkmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color.pmindigo.n500)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }

    private var tabBarPreviewSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.preview)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        TabBarPreview(selectedMode: store.defaultPromiseTabMode)
          .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.promiseTabModePreviewHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }
  }

  // MARK: - TabBarPreview

  private struct TabBarPreview: View {
    let selectedMode: String

    var body: some View {
      if #available(iOS 26.0, *) {
        ios26TabBarPreview
      } else {
        fallbackTabBarPreview
      }
    }

    @available(iOS 26.0, *)
    private var ios26TabBarPreview: some View {
      HStack(spacing: 8) {
        TabItemView(icon: "house.fill", label: LocalizedStrings.SettingsStrings.tabHome, isSelected: false)
        TabItemView(
          icon: selectedMode == "group" ? "person.3.fill" : "person.fill",
          label: selectedMode == "group" ? LocalizedStrings.SettingsStrings.tabGroup : LocalizedStrings.SettingsStrings.tabOwn,
          isSelected: true
        )
        TabItemView(icon: "calendar", label: LocalizedStrings.SettingsStrings.tabCalendar, isSelected: false)
        TabItemView(icon: "gearshape.fill", label: LocalizedStrings.SettingsStrings.tabSettings, isSelected: false)
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 24)
          .fill(.regularMaterial.opacity(0.7))
      )
      .frame(height: 76)
    }

    private var fallbackTabBarPreview: some View {
      HStack(spacing: 8) {
        TabItemView(icon: "house.fill", label: LocalizedStrings.SettingsStrings.tabHome, isSelected: false)
        TabItemView(
          icon: selectedMode == "group" ? "person.3.fill" : "person.fill",
          label: selectedMode == "group" ? LocalizedStrings.SettingsStrings.tabGroup : LocalizedStrings.SettingsStrings.tabOwn,
          isSelected: true
        )
        TabItemView(icon: "calendar", label: LocalizedStrings.SettingsStrings.tabCalendar, isSelected: false)
        TabItemView(icon: "gearshape.fill", label: LocalizedStrings.SettingsStrings.tabSettings, isSelected: false)
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 24)
          .fill(Color.white.opacity(0.1))
      )
      .frame(height: 76)
    }
  }

  // MARK: - TabItemView

  private struct TabItemView: View {
    let icon: String
    let label: String
    let isSelected: Bool

    var body: some View {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 22, weight: .medium))
          .foregroundStyle(isSelected ? Color.pmindigo.n500 : Color.pmtext.secondary)

        Text(label)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(isSelected ? Color.pmindigo.n500 : Color.pmtext.secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background(
        Group {
          if isSelected {
            if #available(iOS 26.0, *) {
              Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
              Capsule()
                .fill(Color.white.opacity(0.2))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
          }
        }
      )
    }
  }
}

// MARK: - ConflictThresholdSettings Namespace

public enum ConflictThresholdSettings {}

extension ConflictThresholdSettings {
  static let presets: [Int] = [0, 15, 30, 60]
  static let customRange: ClosedRange<Int> = 1...120
}

// MARK: - ConflictThresholdSettings Feature

extension ConflictThresholdSettings {

  @Reducer
  public struct Feature {
    @Dependency(\.authClient) var authClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      var threshold: Int = 0
      var isLoading: Bool = true
      var isCustomMode: Bool = false
      var customInputText: String = ""

      public init() {}
    }

    @CasePathable
    public enum Action: Equatable, Sendable {
      case view(View)
      case `internal`(Internal)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case thresholdSelected(Int)
      case customModeTapped
      case customInputChanged(String)
      case customInputCommitted
    }

    @CasePathable
    public enum Internal: Equatable, Sendable {
      case settingsLoaded(Int)
      case updateCompleted
      case updateFailed
    }

    private enum CancelID {
      case thresholdUpdate
      case debounce
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            state.isLoading = true
            return .run { send in
              guard let userId = await authClient.currentUser()?.uid else { return }
              do {
                let settings = try await userSettingsClient.fetchSettings(userId)
                await send(.internal(.settingsLoaded(settings.conflictDetectionThreshold)))
              } catch {
                await send(.internal(.updateFailed))
              }
            }

          case .thresholdSelected(let value):
            state.isCustomMode = false
            state.threshold = value
            return .run { [threshold = value] send in
              await hapticFeedback.selection()
              guard let userId = await authClient.currentUser()?.uid else { return }
              do {
                try await userSettingsClient.updateConflictDetectionThreshold(userId, threshold)
                await send(.internal(.updateCompleted))
              } catch {
                await send(.internal(.updateFailed))
              }
            }
            .cancellable(id: CancelID.thresholdUpdate, cancelInFlight: true)

          case .customModeTapped:
            state.isCustomMode = true
            state.customInputText = state.threshold > 0 ? "\(state.threshold)" : ""
            return .none

          case .customInputChanged(let text):
            let filtered = text.filter { $0.isNumber }
            state.customInputText = filtered
            return .run { send in
              try await Task.sleep(for: .milliseconds(500))
              await send(.view(.customInputCommitted))
            }
            .cancellable(id: CancelID.debounce, cancelInFlight: true)

          case .customInputCommitted:
            guard let value = Int(state.customInputText) else { return .none }
            let clamped = ConflictThresholdSettings.customRange.clamp(value)
            state.threshold = clamped
            state.customInputText = "\(clamped)"
            return .run { [threshold = clamped] send in
              await hapticFeedback.selection()
              guard let userId = await authClient.currentUser()?.uid else { return }
              do {
                try await userSettingsClient.updateConflictDetectionThreshold(userId, threshold)
                await send(.internal(.updateCompleted))
              } catch {
                await send(.internal(.updateFailed))
              }
            }
            .cancellable(id: CancelID.thresholdUpdate, cancelInFlight: true)
          }

        case .internal(let internalAction):
          switch internalAction {
          case .settingsLoaded(let threshold):
            state.threshold = threshold
            state.isLoading = false
            if !ConflictThresholdSettings.presets.contains(threshold) {
              state.isCustomMode = true
              state.customInputText = "\(threshold)"
            }
            return .none

          case .updateCompleted:
            return .none

          case .updateFailed:
            state.isLoading = false
            return .none
          }
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      Group {
        if store.isLoading {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          ScrollView {
            VStack(spacing: 16) {
              headerDescription
              exampleSection
              thresholdSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
          }
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .auroraBackground()
      .navigationTitle("약속 사이 여유 시간")
      .navigationBarTitleDisplayMode(.inline)
      .onTapGesture {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private let thresholdOptions: [(value: Int, label: String)] = [
      (0,  "겹칠 때만"),
      (15, "15분"),
      (30, "30분"),
      (60, "1시간"),
    ]

    private var thresholdDescription: String {
      let t = store.threshold
      if t == 0 {
        return "시간이 겹치는 일정만 충돌로 감지해요."
      }
      if t >= 60 {
        let hours = t / 60
        let mins = t % 60
        if mins == 0 {
          return "약속 사이 최소 \(hours)시간의 여유 시간을 두고 충돌을 판단해요."
        }
        return "약속 사이 최소 \(hours)시간 \(mins)분의 여유 시간을 두고 충돌을 판단해요."
      }
      return "약속 사이 최소 \(t)분의 여유 시간을 두고 충돌을 판단해요."
    }

    private var currentThresholdLabel: String {
      if store.isCustomMode {
        return "\(store.threshold)분"
      }
      return thresholdOptions.first { $0.value == store.threshold }?.label ?? "겹칠 때만"
    }

    private var headerDescription: some View {
      Text("새 약속을 만들 때, 기존 일정과의 시간 간격이 설정한 여유 시간보다 짧으면 충돌로 알려드려요.")
        .font(.system(size: 14))
        .foregroundStyle(Color.pmtext.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var thresholdSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("여유 시간 설정")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          HStack {
            Image(systemName: "exclamationmark.triangle")
              .font(.body)
              .foregroundStyle(Color.pmindigo.n500)
              .frame(width: 24)

            Text("최소 여유 시간")
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Spacer()

            Menu {
              ForEach(thresholdOptions, id: \.value) { option in
                Button {
                  store.send(.view(.thresholdSelected(option.value)), animation: .default)
                } label: {
                  if !store.isCustomMode && store.threshold == option.value {
                    Label(option.label, systemImage: "checkmark")
                  } else {
                    Text(option.label)
                  }
                }
              }

              Divider()

              Button {
                store.send(.view(.customModeTapped), animation: .default)
              } label: {
                if store.isCustomMode {
                  Label("직접 설정", systemImage: "checkmark")
                } else {
                  Text("직접 설정")
                }
              }
            } label: {
              HStack(spacing: 4) {
                Text(currentThresholdLabel)
                  .font(.system(size: 15))
                  .foregroundStyle(Color.pmindigo.n500)

                Image(systemName: "chevron.up.chevron.down")
                  .font(.system(size: 11))
                  .foregroundStyle(Color.pmtext.secondary)
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)

          if store.isCustomMode {
            Divider()
            HStack(spacing: 6) {
              TextField("", text: $store.customInputText.sending(\.view.customInputChanged))
                .keyboardType(.numberPad)
                .font(.system(size: 20, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(width: 64, height: 40)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.pmgray.n400.opacity(0.1))
                )
                .toolbar {
                  ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                      UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                      Image(systemName: "keyboard.chevron.compact.down")
                    }
                  }
                }
              Text("분")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.pmtext.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
          }
        }
        .adaptiveGlassCard()

        Text(thresholdDescription)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
          .animation(.default, value: store.threshold)
      }
    }

    private var exampleSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("미리보기")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        ConflictThresholdPreview(threshold: store.threshold)

        Text("여유 시간 설정에 따라 충돌 여부가 달라져요.")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }
  }

  // MARK: - ConflictThresholdPreview (Timeline)

  private struct ConflictThresholdPreview: View {
    let threshold: Int
    @State private var showConflictTooltip = false

    // 타임라인: 0 = 오후 1시, 300 = 오후 6시
    private let totalMinutes: CGFloat = 300
    private let myStart: CGFloat = 60   // 오후 2시
    private let myEnd: CGFloat = 180    // 오후 4시
    private let hourMinutes = [0, 60, 120, 180, 240, 300]
    private let hourLabels = ["1시", "2시", "3시", "4시", "5시", "6시"]

    private struct Scenario {
      let title: String
      let emoji: String
      let start: CGFloat
      let end: CGFloat
      let overlapMinutes: Int
      let gapMinutes: Int
    }

    // 시나리오:
    // 점심 약속: 1:50~2:10, 내 약속(2~4시)과 10분 겹침
    // 팀 미팅: 4:10~5:00, 내 약속과 gap = 10분, 겹침 없음
    // 저녁 약속: 4:30~6:00, 내 약속과 gap = 30분, 겹침 없음
    // 오전 운동: 12:00~1:30, 내 약속과 gap = 30분, 겹침 없음
    private let scenarios: [Scenario] = [
      .init(title: "점심 약속", emoji: "🍜",  start: 50,  end:  70, overlapMinutes: 10, gapMinutes: 0),
      .init(title: "팀 미팅",  emoji: "📌",  start: 190, end: 240, overlapMinutes: 0,  gapMinutes: 10),
      .init(title: "저녁 약속", emoji: "🍽️", start: 210, end: 300, overlapMinutes: 0,  gapMinutes: 30),
      .init(title: "오전 운동", emoji: "🏃",  start: -60, end:  30, overlapMinutes: 0,  gapMinutes: 30),
    ]

    private func frac(_ m: CGFloat) -> CGFloat { m / totalMinutes }

    private func formatTimeLabel(_ m: CGFloat) -> String {
      let totalFromNoon = Int(m) + 60
      let hour = totalFromNoon / 60
      let min = totalFromNoon % 60
      let displayHour = hour == 0 ? 12 : hour
      return String(format: "%d:%02d", displayHour, min)
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        // 타임라인 + 새로 만드는 약속 (카드 밖)
        VStack(alignment: .leading, spacing: 4) {
          timeAxis

          Text("새로 만드는 약속")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.pmindigo.n500)

          myEventBar
        }

        // 기존 일정 카드 (plain background)
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 4) {
            Text("기존 일정")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(Color.pmtext.secondary)
            Rectangle()
              .fill(Color.pmgray.n400.opacity(0.3))
              .frame(height: 0.5)
          }

          ForEach(Array(scenarios.enumerated()), id: \.offset) { index, scenario in
            eventRow(scenario)
            if index < scenarios.count - 1 {
              Divider()
                .padding(.leading, 24)
            }
          }
        }
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .fill(Color.pmgray.n400.opacity(0.08))
        )

        // 충돌 알림 미리보기 (adaptive glass + popover)
        if !conflictScenarios.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("약속 생성 시 이렇게 알려드려요")
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(Color.pmtext.secondary)

            conflictFloatingPreview
          }
        }
      }
      .padding(16)
      .adaptiveGlassBackground()
      .animation(.easeInOut(duration: 0.2), value: threshold)
    }

    private var conflictScenarios: [Scenario] {
      scenarios.filter { $0.overlapMinutes > 0 || (threshold > 0 && $0.gapMinutes < threshold) }
    }

    // MARK: - Conflict Floating Preview

    private var conflictFloatingPreview: some View {
      let conflicts = conflictScenarios

      return Button {
        showConflictTooltip = true
      } label: {
        VStack(alignment: .leading, spacing: 4) {
          ProBadge()

          HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 12))
              .foregroundStyle(Color.pmwarning.n500)

            if conflicts.count == 1, let first = conflicts.first {
              let text: String = {
                if first.overlapMinutes > 0 {
                  return "'\(first.title)'과(와) \(first.overlapMinutes)분 겹쳐요"
                } else if first.gapMinutes > 0 {
                  return "'\(first.title)'과(와) 여유 \(first.gapMinutes)분이에요"
                } else {
                  return "'\(first.title)'과(와) 일정이 겹쳐요"
                }
              }()
              Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Color.pmtext.primary)
                .lineLimit(1)
            } else {
              Text("\(conflicts.count)건의 일정이 겹쳐요")
                .font(.system(size: 11))
                .foregroundStyle(Color.pmtext.primary)
            }

            Spacer(minLength: 0)

            Image(systemName: "info.circle")
              .font(.system(size: 11))
              .foregroundStyle(Color.pmtext.secondary)
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveGlassCard(cornerRadius: 10)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .popover(isPresented: $showConflictTooltip, arrowEdge: .bottom) {
        let conflictInfos: [ConflictInfo] = conflicts.map { scenario in
          ConflictInfo(
            title: scenario.title,
            overlapMinutes: scenario.overlapMinutes,
            gapMinutes: scenario.gapMinutes,
            startAt: scenarioToDate(scenario.start),
            endAt: scenarioToDate(scenario.end),
            emoji: scenario.emoji,
            severity: .confirmed
          )
        }
        ConflictTooltip(
          newEventTitle: "새로 만드는 약속",
          newEventStartAt: scenarioToDate(myStart),
          newEventEndAt: scenarioToDate(myEnd),
          conflicts: conflictInfos
        )
        .presentationCompactAdaptation(.popover)
      }
    }

    // MARK: - Date Helpers

    private var baseDate: Date {
      Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func scenarioToDate(_ minutes: CGFloat) -> Date {
      baseDate.addingTimeInterval(TimeInterval(minutes) * 60)
    }

    // MARK: - Time Axis

    private var timeAxis: some View {
      GeometryReader { geo in
        let w = geo.size.width

        Path { p in
          p.move(to: .init(x: 0, y: 16))
          p.addLine(to: .init(x: w, y: 16))
        }
        .stroke(Color.pmgray.n400.opacity(0.4), lineWidth: 0.5)

        ForEach(Array(hourMinutes.enumerated()), id: \.offset) { i, minutes in
          let x = frac(CGFloat(minutes)) * w

          Path { p in
            p.move(to: .init(x: x, y: 12))
            p.addLine(to: .init(x: x, y: 20))
          }
          .stroke(Color.pmgray.n400.opacity(0.4), lineWidth: 0.5)

          Text(hourLabels[i])
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Color.pmtext.secondary)
            .position(x: x, y: 6)
        }
      }
      .frame(height: 22)
    }

    // MARK: - My Event Bar

    private var myEventBar: some View {
      GeometryReader { geo in
        let w = geo.size.width
        let x = frac(myStart) * w
        let barW = frac(myEnd - myStart) * w

        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 5)
            .fill(Color.pmindigo.n500)
            .frame(width: barW, height: 26)
            .offset(x: x)

          Text("\(formatTimeLabel(myStart)) ~ \(formatTimeLabel(myEnd))")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .offset(x: x + 6)
        }
        .frame(maxHeight: .infinity, alignment: .center)
      }
      .frame(height: 26)
    }

    // MARK: - Event Row

    private func eventRow(_ scenario: Scenario) -> some View {
      let isConflict = scenario.overlapMinutes > 0 || (threshold > 0 && scenario.gapMinutes < threshold)
      let barStart = max(scenario.start, 0)
      let barEnd = min(scenario.end, totalMinutes)

      return VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 4) {
          Text(scenario.emoji)
            .font(.system(size: 12))
          Text(scenario.title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.pmtext.primary)

          Text("\(formatTimeLabel(scenario.start)) ~ \(formatTimeLabel(scenario.end))")
            .font(.system(size: 10))
            .foregroundStyle(Color.pmtext.secondary.opacity(0.7))

          Spacer()

          if scenario.overlapMinutes > 0 {
            Text("\(scenario.overlapMinutes)분 겹침")
              .font(.system(size: 10))
              .foregroundStyle(Color.pmtext.secondary)
          } else {
            Text("여유 \(scenario.gapMinutes)분")
              .font(.system(size: 10))
              .foregroundStyle(Color.pmtext.secondary)
          }

          HStack(spacing: 3) {
            Image(systemName: isConflict ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
              .font(.system(size: 11))
            Text(isConflict ? "충돌" : "여유")
              .font(.system(size: 11, weight: .semibold))
          }
          .foregroundStyle(isConflict ? Color.pmwarning.n500 : Color.pmsuccess.n500)
          .animation(.easeInOut(duration: 0.2), value: isConflict)
        }

        GeometryReader { geo in
          let w = geo.size.width
          let barX = frac(barStart) * w
          let barW = frac(barEnd - barStart) * w
          let barColor = isConflict ? Color.pmwarning.n500 : Color.pmsuccess.n500

          ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
              .fill(barColor.opacity(isConflict ? 0.5 : 0.35))
              .frame(width: barW, height: 20)
              .offset(x: barX)
              .animation(.easeInOut(duration: 0.2), value: isConflict)
          }
          .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 20)
      }
    }
  }
}

extension ClosedRange where Bound == Int {
  fileprivate func clamp(_ value: Bound) -> Bound {
    return Swift.min(Swift.max(lowerBound, value), upperBound)
  }
}

// MARK: - CalendarSyncError Localization

extension CalendarSyncError {
  var localizedMessage: String {
    switch self {
    case .noWritePermission: return LocalizedStrings.Error.calendarNoWritePermission
    case .fetchFailed(_): return LocalizedStrings.Error.calendarFetchFailed
    case .syncFailed(_): return LocalizedStrings.Error.calendarSyncFailed
    }
  }
}

// MARK: - UserProfileError Localization

extension UserProfileError {
  var localizedMessage: String {
    switch self {
    case .invalidData: return LocalizedStrings.Error.userInvalidData
    case .userNotFound: return LocalizedStrings.Error.userNotFound
    case .uploadFailed: return LocalizedStrings.Error.userUploadFailed
    case .networkError: return LocalizedStrings.Error.userNetworkError
    case .authenticationRequired: return LocalizedStrings.Error.userAuthRequired
    case .permissionDenied: return LocalizedStrings.Error.userPermissionDenied
    }
  }
}

// MARK: - AppConfigClientError Localization

extension AppConfigClientError {
  var localizedMessage: String {
    switch self {
    case .fetchFailed(_): return LocalizedStrings.Error.appConfigFetchFailed
    case .invalidVersion(_): return LocalizedStrings.Error.appConfigInvalidVersion
    }
  }
}
