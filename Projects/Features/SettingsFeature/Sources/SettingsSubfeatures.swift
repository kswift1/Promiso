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
  static let presets: [Int] = [0, 5, 15, 30, 60]
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
              thresholdSection
              exampleSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
          }
        }
      }
      .auroraBackground()
      .navigationTitle("충돌 감지 기준")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private let thresholdOptions: [(value: Int, label: String)] = [
      (0, "모든 겹침"),
      (5, "5분 초과"),
      (15, "15분 초과"),
      (30, "30분 초과"),
      (60, "1시간 초과"),
    ]

    private var currentThresholdLabel: String {
      if store.isCustomMode {
        return "\(store.threshold)분 초과"
      }
      return thresholdOptions.first { $0.value == store.threshold }?.label ?? "모든 겹침"
    }

    private var thresholdSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("충돌 기준 시간")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          HStack {
            Image(systemName: "exclamationmark.triangle")
              .font(.body)
              .foregroundStyle(Color.pmindigo.n500)
              .frame(width: 24)

            Text("겹침 기준")
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
              Text("분 초과")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.pmtext.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
          }
        }
        .adaptiveGlassCard()

        Text("약속이나 일정이 겹치더라도 설정한 시간보다 짧게 겹치면 충돌 경고를 표시하지 않아요.")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    private var exampleSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("미리보기")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        ConflictThresholdPreview(threshold: store.threshold)

        Text("오후 2시~4시의 내 약속 기준으로, 다른 일정의 겹침이 충돌로 표시되는지 확인할 수 있어요.")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }
  }

  // MARK: - ConflictThresholdPreview (Timeline)

  private struct ConflictThresholdPreview: View {
    let threshold: Int

    // 타임라인: 0 = 오후 1시, 240 = 오후 5시
    private let totalMinutes: CGFloat = 240
    private let myStart: CGFloat = 60   // 오후 2시
    private let myEnd: CGFloat = 180    // 오후 4시
    private let hourMinutes = [0, 60, 120, 180, 240]
    private let hourLabels = ["1시", "2시", "3시", "4시", "5시"]

    private struct Scenario {
      let title: String
      let emoji: String
      let start: CGFloat
      let end: CGFloat
      let overlapMinutes: Int
    }

    // 겹침 계산:
    // 팀 미팅: 3:50~4:40, 내 약속(2~4시)과 3:50~4:00 = 10분 겹침
    // 저녁 약속: 3:35~4:45, 내 약속과 3:35~4:00 = 25분 겹침
    // 오전 운동: 1:10~2:50, 내 약속과 2:00~2:50 = 50분 겹침
    private let scenarios: [Scenario] = [
      .init(title: "팀 미팅", emoji: "📌", start: 170, end: 220, overlapMinutes: 10),
      .init(title: "저녁 약속", emoji: "🍽️", start: 155, end: 225, overlapMinutes: 25),
      .init(title: "오전 운동", emoji: "🏃", start: 10, end: 110, overlapMinutes: 50),
    ]

    private func frac(_ m: CGFloat) -> CGFloat { m / totalMinutes }

    private func formatTime(_ m: CGFloat) -> String {
      let total = Int(m)
      let hour = 1 + total / 60
      let min = total % 60
      return String(format: "%d:%02d", hour, min)
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        timeAxis

        VStack(alignment: .leading, spacing: 3) {
          Text("내 약속")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.pmindigo.n500)
          myEventBar
        }

        Divider()

        ForEach(Array(scenarios.enumerated()), id: \.offset) { index, scenario in
          eventRow(scenario)
          if index < scenarios.count - 1 {
            Divider()
              .padding(.leading, 24)
          }
        }
      }
      .padding(16)
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

          Text("오후 2시 – 4시")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .offset(x: x + 8)
        }
        .frame(maxHeight: .infinity, alignment: .center)
      }
      .frame(height: 26)
    }

    // MARK: - Event Row

    private func eventRow(_ scenario: Scenario) -> some View {
      let isConflict = scenario.overlapMinutes > threshold
      let oStart = max(scenario.start, myStart)
      let oEnd = min(scenario.end, myEnd)

      return VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 4) {
          Text(scenario.emoji)
            .font(.system(size: 12))
          Text("\(scenario.title) (\(formatTime(scenario.start))~\(formatTime(scenario.end)))")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.pmtext.primary)

          Text("\(scenario.overlapMinutes)분 겹침")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)

          Spacer()

          HStack(spacing: 3) {
            Image(systemName: isConflict ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
              .font(.system(size: 11))
            Text(isConflict ? "충돌" : "무시")
              .font(.system(size: 11, weight: .semibold))
          }
          .foregroundStyle(isConflict ? Color.pmwarning.n500 : Color.pmsuccess.n500)
          .animation(.easeInOut(duration: 0.2), value: isConflict)
        }

        GeometryReader { geo in
          let w = geo.size.width
          let barX = frac(scenario.start) * w
          let barW = frac(scenario.end - scenario.start) * w
          let overlapX = frac(oStart) * w
          let overlapW = frac(oEnd - oStart) * w
          let overlapColor = isConflict ? Color.pmwarning.n500 : Color.pmsuccess.n500

          ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.pmgray.n400.opacity(0.2))
              .frame(width: barW, height: 20)
              .offset(x: barX)

            RoundedRectangle(cornerRadius: 4)
              .fill(overlapColor.opacity(isConflict ? 0.5 : 0.35))
              .frame(width: overlapW, height: 20)
              .offset(x: overlapX)
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
