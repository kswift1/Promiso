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
