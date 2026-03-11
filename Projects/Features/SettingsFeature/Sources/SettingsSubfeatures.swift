import Clients
import ComposableArchitecture
import PromisoShared
import SharedFeature
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
      @Shared(.appStorage(AppConstants.UserDefaults.calendarStartOnMonday)) public var calendarStartOnMonday: Bool = true
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
      case calendarStartDaySelected(Bool)
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

          case .calendarStartDaySelected(let startOnMonday):
            state.$calendarStartOnMonday.withLock { $0 = startOnMonday }
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
          calendarStartDaySection
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

    private var calendarStartDaySection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.calendarStartDaySection)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          calendarStartDayRow(
            startOnMonday: false,
            title: LocalizedStrings.SettingsStrings.calendarStartSunday,
            weekdays: LocalizedStrings.Calendar.orderedWeekdaySymbols(startOnMonday: false).joined(separator: " ")
          )
          Divider()
            .padding(.leading, 48)
          calendarStartDayRow(
            startOnMonday: true,
            title: LocalizedStrings.SettingsStrings.calendarStartMonday,
            weekdays: LocalizedStrings.Calendar.orderedWeekdaySymbols(startOnMonday: true).joined(separator: " ")
          )
        }
        .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.calendarStartDayHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    private func calendarStartDayRow(startOnMonday: Bool, title: String, weekdays: String) -> some View {
      Button {
        store.send(.view(.calendarStartDaySelected(startOnMonday)))
      } label: {
        HStack(spacing: 12) {
          Image(systemName: store.calendarStartOnMonday == startOnMonday ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 20))
            .foregroundStyle(store.calendarStartOnMonday == startOnMonday ? Color.pmindigo.n500 : Color.pmgray.n400)
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 2) {
            Text(title)
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundStyle(Color.pmtext.primary)

            Text(weekdays)
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()
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

// MARK: - TabSettings Namespace

public enum TabSettings {}

// MARK: - TabSettings Feature

extension TabSettings {

  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      @Shared(.appStorage(AppConstants.UserDefaults.defaultPromiseTabMode)) public var defaultPromiseTabMode: String = "group"
      @Shared(.appStorage(AppConstants.UserDefaults.defaultCalendarDisplayMode)) public var defaultCalendarDisplayMode: String = "month"

      public init() {}
    }

    public enum Action: Equatable, Sendable {
      case view(View)
    }

    public enum View: Equatable, Sendable {
      case onAppear
      case promiseTabModeChanged(String)
      case calendarDisplayModeChanged(String)
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .none

          case .promiseTabModeChanged(let mode):
            state.$defaultPromiseTabMode.withLock { $0 = mode }
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .calendarDisplayModeChanged(let mode):
            state.$defaultCalendarDisplayMode.withLock { $0 = mode }
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
        VStack(spacing: 24) {
          promiseTabModeSection
          calendarDisplayModeSection
          tabBarPreviewSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.tabSettingsMenu)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Promise Tab Mode Section

    private var promiseTabModeSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.promiseTabModeDefault)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          promiseTabModeRow(mode: "group", icon: "person.3.fill", title: LocalizedStrings.SettingsStrings.promiseTabModeGroup, description: LocalizedStrings.SettingsStrings.promiseTabModeGroupDescription)
          Divider()
            .padding(.leading, 48)
          promiseTabModeRow(mode: "own", icon: "person.fill", title: LocalizedStrings.SettingsStrings.promiseTabModeOwn, description: LocalizedStrings.SettingsStrings.promiseTabModeOwnDescription)
        }
        .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.promiseTabModeHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    private func promiseTabModeRow(mode: String, icon: String, title: String, description: String) -> some View {
      Button {
        store.send(.view(.promiseTabModeChanged(mode)))
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

    // MARK: - Calendar Display Mode Section

    private var calendarDisplayModeSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.calendarDisplayModeDefault)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          ForEach(Array(CalendarDisplayMode.allCases.enumerated()), id: \.element) { index, mode in
            if index > 0 {
              Divider()
                .padding(.leading, 48)
            }
            calendarDisplayModeRow(mode: mode)
          }
        }
        .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.calendarDisplayModeHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    private func calendarDisplayModeRow(mode: CalendarDisplayMode) -> some View {
      Button {
        store.send(.view(.calendarDisplayModeChanged(mode.rawValue)))
      } label: {
        HStack(spacing: 12) {
          Image(systemName: mode.iconName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 20)

          VStack(alignment: .leading, spacing: 2) {
            Text(mode.label)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Text(mode.settingsDescription)
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()

          if store.defaultCalendarDisplayMode == mode.rawValue {
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

    // MARK: - Tab Bar Preview Section

    private var tabBarPreviewSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.preview)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        TabBarPreview(
          promiseMode: store.defaultPromiseTabMode,
          calendarDisplayMode: store.defaultCalendarDisplayMode
        )
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
    let promiseMode: String
    let calendarDisplayMode: String

    private var calendarIcon: String {
      (CalendarDisplayMode(rawValue: calendarDisplayMode) ?? .month).iconName
    }

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
          icon: promiseMode == "group" ? "person.3.fill" : "person.fill",
          label: promiseMode == "group" ? LocalizedStrings.SettingsStrings.tabGroup : LocalizedStrings.SettingsStrings.tabOwn,
          isSelected: true
        )
        TabItemView(icon: calendarIcon, label: LocalizedStrings.SettingsStrings.tabCalendar, isSelected: true)
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
          icon: promiseMode == "group" ? "person.3.fill" : "person.fill",
          label: promiseMode == "group" ? LocalizedStrings.SettingsStrings.tabGroup : LocalizedStrings.SettingsStrings.tabOwn,
          isSelected: true
        )
        TabItemView(icon: calendarIcon, label: LocalizedStrings.SettingsStrings.tabCalendar, isSelected: true)
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
      var isEnabled: Bool = true
      var threshold: Int = 0
      var isLoading: Bool = true
      var isCustomMode: Bool = false
      var customInputText: String = ""
      var isPro: Bool

      public init(isPro: Bool) {
        self.isPro = isPro
        self.isEnabled = isPro
      }
    }

    @CasePathable
    public enum Action: Equatable, Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case enabledToggled(Bool)
      case thresholdSelected(Int)
      case customModeTapped
      case customInputChanged(String)
      case customInputCommitted
      case proFeatureTapped
    }

    @CasePathable
    public enum Internal: Equatable, Sendable {
      case settingsLoaded(Int)
      case updateCompleted
      case updateFailed
    }

    public enum Delegate: Equatable, Sendable {
      case proPlanRequested
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

          case .enabledToggled(let enabled):
            guard state.isPro else {
              return .run { send in
                await hapticFeedback.selection()
                await send(.delegate(.proPlanRequested))
              }
            }
            state.isEnabled = enabled
            if !enabled {
              // 비활성화: 서버에 -1 저장
              return .run { send in
                await hapticFeedback.selection()
                guard let userId = await authClient.currentUser()?.uid else { return }
                do {
                  try await userSettingsClient.updateConflictDetectionThreshold(userId, -1)
                  await send(.internal(.updateCompleted))
                } catch {
                  await send(.internal(.updateFailed))
                }
              }
              .cancellable(id: CancelID.thresholdUpdate, cancelInFlight: true)
            } else {
              // 활성화: 현재 threshold 값으로 서버 업데이트
              let threshold = state.threshold
              return .run { [threshold] send in
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

          case .thresholdSelected(let value):
            guard state.isPro else { return .none }
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
            guard state.isPro else { return .none }
            state.isCustomMode = true
            state.customInputText = state.threshold > 0 ? "\(state.threshold)" : ""
            return .none

          case .customInputChanged(let text):
            guard state.isPro else { return .none }
            let filtered = text.filter { $0.isNumber }
            state.customInputText = filtered
            return .run { send in
              try await Task.sleep(for: .milliseconds(500))
              await send(.view(.customInputCommitted))
            }
            .cancellable(id: CancelID.debounce, cancelInFlight: true)

          case .customInputCommitted:
            guard state.isPro else { return .none }
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

          case .proFeatureTapped:
            guard !state.isPro else { return .none }
            return .run { send in
              await hapticFeedback.selection()
              await send(.delegate(.proPlanRequested))
            }
          }

        case .internal(let internalAction):
          switch internalAction {
          case .settingsLoaded(let threshold):
            if !state.isPro || threshold < 0 {
              state.isEnabled = false
              state.threshold = threshold < 0 ? 0 : threshold
            } else {
              state.isEnabled = true
              state.threshold = threshold
              if !ConflictThresholdSettings.presets.contains(threshold) {
                state.isCustomMode = true
                state.customInputText = "\(threshold)"
              }
            }
            state.isLoading = false
            return .none

          case .updateCompleted:
            return .none

          case .updateFailed:
            state.isLoading = false
            return .none
          }

        case .delegate:
          return .none
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

              thresholdSection
                .opacity(store.isEnabled && store.isPro ? 1 : 0.35)
                .allowsHitTesting(store.isPro ? store.isEnabled : true)
                .overlay {
                  if !store.isPro {
                    Color.clear
                      .contentShape(Rectangle())
                      .onTapGesture {
                        store.send(.view(.proFeatureTapped))
                      }
                  }
                }

              exampleSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
          }
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.conflictDetectionTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          HStack(spacing: 6) {
            ProBadge()
            Text(LocalizedStrings.SettingsStrings.conflictDetectionTitle)
              .font(.headline)
          }
        }
      }
      .onTapGesture {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private var thresholdOptions: [(value: Int, label: String)] {
      [
        (0,  LocalizedStrings.SettingsStrings.conflictDetectionOverlapOnly),
        (15, "15분"),
        (30, "30분"),
        (60, "1시간"),
      ]
    }

    private var thresholdDescription: String {
      let t = store.threshold
      if t == 0 {
        return LocalizedStrings.SettingsStrings.conflictDetectionOverlapOnlyHint
      }
      if t >= 60 {
        let hours = t / 60
        let mins = t % 60
        if mins == 0 {
          return LocalizedStrings.SettingsStrings.conflictDetectionThresholdDescriptionHours(hours)
        }
        return LocalizedStrings.SettingsStrings.conflictDetectionThresholdDescriptionHoursMinutes(hours, mins)
      }
      return LocalizedStrings.SettingsStrings.conflictDetectionThresholdDescriptionMinutes(t)
    }

    private var currentThresholdLabel: String {
      if store.isCustomMode {
        return LocalizedStrings.SettingsStrings.conflictDetectionCurrentMinutes(store.threshold)
      }
      return thresholdOptions.first { $0.value == store.threshold }?.label ?? LocalizedStrings.SettingsStrings.conflictDetectionOverlapOnly
    }

    private var headerDescription: some View {
      HStack(alignment: .center, spacing: 12) {
        Text(LocalizedStrings.SettingsStrings.conflictDetectionDescription)
          .font(.system(size: 14))
          .foregroundStyle(Color.pmtext.secondary)

        Spacer()

        Toggle("", isOn: Binding(
          get: { store.isEnabled },
          set: { store.send(.view(.enabledToggled($0)), animation: .default) }
        ))
        .labelsHidden()
        .tint(Color.pmindigo.n500)
        .allowsHitTesting(store.isPro)
        .overlay {
          if !store.isPro {
            Color.clear
              .contentShape(Rectangle())
              .onTapGesture {
                store.send(.view(.proFeatureTapped))
              }
          }
        }
      }
      .padding(.horizontal, 4)
    }

    private var thresholdSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.conflictDetectionThresholdSection)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          HStack {
            Text(LocalizedStrings.SettingsStrings.conflictDetectionMinThreshold)
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
                  Label(LocalizedStrings.SettingsStrings.conflictDetectionCustom, systemImage: "checkmark")
                } else {
                  Text(LocalizedStrings.SettingsStrings.conflictDetectionCustom)
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
              Text(LocalizedStrings.SettingsStrings.conflictDetectionMinuteUnit)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.pmtext.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
          }
        }
        .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.conflictDetectionThresholdHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    private var exampleSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.conflictDetectionExample)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        ConflictThresholdPreview(threshold: store.threshold)
      }
    }
  }

  // MARK: - ConflictThresholdPreview (Timeline)

  private struct ConflictThresholdPreview: View {
    let threshold: Int
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
    private let scenarios: [Scenario] = [
      .init(title: "점심 약속", emoji: "🍜",  start: 50,  end:  70, overlapMinutes: 10, gapMinutes: 0),
      .init(title: "팀 미팅",  emoji: "📌",  start: 190, end: 240, overlapMinutes: 0,  gapMinutes: 10),
      .init(title: "저녁 약속", emoji: "🍽️", start: 210, end: 300, overlapMinutes: 0,  gapMinutes: 30),
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

          Text(LocalizedStrings.SettingsStrings.conflictDetectionNewEvent)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.pmindigo.n500)

          myEventBar
        }

        // 기존 일정 카드 (plain background)
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 4) {
            Text(LocalizedStrings.SettingsStrings.conflictDetectionExistingEvents)
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
            Text(LocalizedStrings.SettingsStrings.conflictDetectionPreviewHint)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(Color.pmtext.secondary)

            conflictFloatingPreview
          }
        }
      }
      .padding(16)
      .staticGlassBackground()
      .animation(.easeInOut(duration: 0.2), value: threshold)
    }

    private var conflictScenarios: [Scenario] {
      scenarios.filter { $0.overlapMinutes > 0 || (threshold > 0 && $0.gapMinutes < threshold) }
    }

    // MARK: - Conflict Floating Preview

    private var conflictFloatingPreview: some View {
      let conflictInfos: [ConflictInfo] = conflictScenarios.map { scenario in
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

      return VStack(alignment: .leading, spacing: 4) {
        ProBadge()
        ProConflictRow(
          conflicts: conflictInfos,
          isChecking: false,
          eventTitle: LocalizedStrings.SettingsStrings.conflictDetectionNewEvent,
          eventStartAt: scenarioToDate(myStart),
          eventEndAt: scenarioToDate(myEnd)
        )
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.pmindigo.n500.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
      .adaptiveGlassCard(cornerRadius: 10)
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
            Text(LocalizedStrings.Shared.conflictOverlapMinutes(scenario.overlapMinutes))
              .font(.system(size: 10))
              .foregroundStyle(Color.pmtext.secondary)
          } else {
            Text(LocalizedStrings.Shared.conflictMarginMinutes(scenario.gapMinutes))
              .font(.system(size: 10))
              .foregroundStyle(Color.pmtext.secondary)
          }

          HStack(spacing: 3) {
            Image(systemName: isConflict ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
              .font(.system(size: 11))
            Text(isConflict ? LocalizedStrings.SettingsStrings.conflictDetectionConflict : LocalizedStrings.SettingsStrings.conflictDetectionMargin)
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

// MARK: - BriefingSettings Namespace

public enum BriefingSettings {}

// MARK: - BriefingSettings Feature

extension BriefingSettings {

  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.notificationClient) var notificationClient

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      var selectedStyle: BriefingStyle = .friendly
      var notificationHour: Int? = nil
      var isLoading: Bool = false
      var hasLoaded: Bool = false
      var isPro: Bool
      @Shared(.appStorage(AppConstants.UserDefaults.briefingStyle)) var briefingStyleRaw: String = BriefingStyle.friendly.rawValue
      var selectedTransports: Set<AvailableTransport> = [.transit, .car]
      var notificationAuthStatus: NotificationAuthorizationStatus = .notDetermined
      @Presents var notificationPermission: NotificationPermission.Feature.State?

      var isNotificationEnabled: Bool { notificationHour != nil }

      public init(isPro: Bool) {
        self.isPro = isPro
      }
    }

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case notificationPermission(PresentationAction<NotificationPermission.Feature.Action>)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case styleSelected(BriefingStyle)
      case transportToggled(AvailableTransport)
      case notificationToggled(Bool)
      case notificationHourChanged(Int)
      case notificationPermissionBannerTapped
      case onSceneActive
      case proFeatureTapped
    }

    @CasePathable
    public enum Internal: Equatable, Sendable {
      case settingsLoaded(BriefingStyle, Int?, Set<AvailableTransport>)
      case notificationAuthStatusLoaded(NotificationAuthorizationStatus)
      case styleSaved
      case notificationHourSaved
      case saveFailed
    }

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case proPlanRequested
    }

    private enum CancelID {
      case save
    }

    public var body: some ReducerOf<Self> {
      let saveNotificationHour = { [hapticFeedback, authClient, userSettingsClient] (hour: Int?) -> Effect<Action> in
        .run { send in
          await hapticFeedback.selection()
          guard let userId = await authClient.currentUser()?.uid else { return }
          do {
            try await userSettingsClient.updateBriefingNotificationHour(userId, hour)
            await send(.internal(.notificationHourSaved))
          } catch {
            await send(.internal(.saveFailed))
          }
        }
        .cancellable(id: CancelID.save, cancelInFlight: true)
      }

      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            guard !state.hasLoaded else { return .none }
            state.isLoading = true
            return .run { send in
              async let authStatus = notificationClient.getAuthorizationStatus()
              guard let userId = await authClient.currentUser()?.uid else {
                await send(.internal(.settingsLoaded(.friendly, nil, [.transit, .car])))
                await send(.internal(.notificationAuthStatusLoaded(authStatus)))
                return
              }
              do {
                let settings = try await userSettingsClient.fetchSettings(userId)
                await send(.internal(.settingsLoaded(settings.briefingStyle, settings.briefingNotificationHour, settings.availableTransports)))
              } catch {
                await send(.internal(.settingsLoaded(.friendly, nil, [.transit, .car])))
              }
              await send(.internal(.notificationAuthStatusLoaded(authStatus)))
            }

          case .styleSelected(let style):
            state.selectedStyle = style
            state.$briefingStyleRaw.withLock { $0 = style.rawValue }
            return .run { [style] send in
              await hapticFeedback.selection()
              guard let userId = await authClient.currentUser()?.uid else { return }
              do {
                try await userSettingsClient.updateBriefingStyle(userId, style)
                await send(.internal(.styleSaved))
              } catch {
                await send(.internal(.saveFailed))
              }
            }
            .cancellable(id: CancelID.save, cancelInFlight: true)

          case .transportToggled(let transport):
            if state.selectedTransports.contains(transport) {
              // 최소 1개는 유지
              guard state.selectedTransports.count > 1 else { return .none }
              state.selectedTransports.remove(transport)
            } else {
              state.selectedTransports.insert(transport)
            }
            let transports = state.selectedTransports
            return .run { [transports] send in
              await hapticFeedback.selection()
              guard let userId = await authClient.currentUser()?.uid else { return }
              do {
                try await userSettingsClient.updateAvailableTransports(userId, transports)
              } catch {
                await send(.internal(.saveFailed))
              }
            }
            .cancellable(id: CancelID.save, cancelInFlight: true)

          case .notificationToggled(let enabled):
            if enabled {
              guard state.notificationAuthStatus.isGranted else {
                state.notificationPermission = NotificationPermission.Feature.State(allowInteractiveDismiss: true)
                return .none
              }
              state.notificationHour = 8
            } else {
              state.notificationHour = nil
            }
            return saveNotificationHour(state.notificationHour)

          case .notificationHourChanged(let hour):
            state.notificationHour = hour
            return saveNotificationHour(hour)

          case .notificationPermissionBannerTapped:
            if state.notificationAuthStatus == .denied {
              return .run { [notificationClient] _ in
                await notificationClient.openNotificationSettings()
              }
            } else {
              state.notificationPermission = NotificationPermission.Feature.State(allowInteractiveDismiss: true)
              return .none
            }

          case .onSceneActive:
            return .run { [notificationClient] send in
              let status = await notificationClient.getAuthorizationStatus()
              await send(.internal(.notificationAuthStatusLoaded(status)))
            }

          case .proFeatureTapped:
            guard !state.isPro else { return .none }
            return .run { send in
              await hapticFeedback.selection()
              await send(.delegate(.proPlanRequested))
            }
          }

        case .internal(let internalAction):
          switch internalAction {
          case .settingsLoaded(let style, let hour, let transports):
            state.selectedStyle = style
            state.notificationHour = hour
            state.selectedTransports = transports
            state.$briefingStyleRaw.withLock { $0 = style.rawValue }
            state.isLoading = false
            state.hasLoaded = true
            return .none

          case .notificationAuthStatusLoaded(let status):
            state.notificationAuthStatus = status
            return .none

          case .styleSaved, .notificationHourSaved:
            return .none

          case .saveFailed:
            // 저장 실패 시 서버 상태로 재동기화
            state.isLoading = true
            return .run { [authClient, userSettingsClient] send in
              guard let userId = await authClient.currentUser()?.uid else {
                await send(.internal(.settingsLoaded(.friendly, nil, [.transit, .car])))
                return
              }
              do {
                let settings = try await userSettingsClient.fetchSettings(userId)
                await send(.internal(.settingsLoaded(settings.briefingStyle, settings.briefingNotificationHour, settings.availableTransports)))
              } catch {
                await send(.internal(.settingsLoaded(.friendly, nil, [.transit, .car])))
              }
            }
          }

        case .delegate:
          return .none

        // MARK: - NotificationPermission

        case .notificationPermission(.presented(.delegate(.permissionChanged(let isGranted)))):
          if isGranted {
            state.notificationAuthStatus = .authorized
            state.notificationHour = 8
            return saveNotificationHour(state.notificationHour)
          } else {
            return .run { [notificationClient] send in
              let status = await notificationClient.getAuthorizationStatus()
              await send(.internal(.notificationAuthStatusLoaded(status)))
            }
          }

        case .notificationPermission(.presented(.delegate(.dismissed))):
          state.notificationPermission = nil
          return .none

        case .notificationPermission:
          return .none
        }
      }
      .ifLet(\.$notificationPermission, action: \.notificationPermission) {
        NotificationPermission.Feature()
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @Environment(\.scenePhase) private var scenePhase

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
              notificationSection
              transportSection
              styleSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
          }
        }
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.briefingSettingsTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          HStack(spacing: 6) {
            ProBadge()
            Text(LocalizedStrings.SettingsStrings.briefingSettingsTitle)
              .font(.headline)
          }
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
          store.send(.view(.onSceneActive))
        }
      }
      .sheet(
        item: $store.scope(
          state: \.notificationPermission,
          action: \.notificationPermission
        )
      ) { permissionStore in
        NotificationPermission.View(store: permissionStore)
          .presentationDetents([.large])
      }
    }

    // MARK: - Style Section

    private var styleSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.briefingStyle)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        Text(LocalizedStrings.SettingsStrings.briefingStyleDescription)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          ForEach(BriefingStyle.allCases, id: \.rawValue) { style in
            styleRow(style: style)
            if style != BriefingStyle.allCases.last {
              Divider()
                .padding(.leading, 48)
            }
          }
        }
        .adaptiveGlassCard()
      }
    }

    private func styleRow(style: BriefingStyle) -> some View {
      let isSelectable = store.isPro
      let isSelected = store.selectedStyle == style

      return Button {
        if isSelectable {
          store.send(.view(.styleSelected(style)))
        } else {
          store.send(.view(.proFeatureTapped))
        }
      } label: {
        HStack(spacing: 12) {
          Image(systemName: iconName(for: style))
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isSelectable ? Color.pmindigo.n500 : Color.pmgray.n400)
            .frame(width: 20)

          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Text(style.displayName)
                .font(.body)
                .foregroundStyle(isSelectable ? Color.pmtext.primary : Color.pmtext.secondary)

            }

            Text(style.description)
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()

          if isSelected {
            Image(systemName: "checkmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color.pmindigo.n500)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .opacity(isSelectable ? 1 : 0.5)
      }
      .buttonStyle(.plain)
    }

    private func iconName(for style: BriefingStyle) -> String {
      switch style {
      case .friendly: return "face.smiling"
      case .humorous: return "theatermasks"
      case .concise: return "text.alignleft"
      case .motivational: return "flame"
      case .calm: return "leaf"
      }
    }

    // MARK: - Transport Section

    private var transportSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.briefingTransport)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        Text(LocalizedStrings.SettingsStrings.briefingTransportDescription)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          ForEach(AvailableTransport.allCases, id: \.self) { transport in
            Button {
              if store.isPro {
                store.send(.view(.transportToggled(transport)))
              } else {
                store.send(.view(.proFeatureTapped))
              }
            } label: {
              HStack(spacing: 12) {
                Image(systemName: transport.iconName)
                  .font(.system(size: 16))
                  .foregroundStyle(Color.pmindigo.n500)
                  .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                  Text(transport.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pmtext.primary)
                }

                Spacer()

                Image(systemName: store.selectedTransports.contains(transport) ? "checkmark.circle.fill" : "circle")
                  .font(.system(size: 20))
                  .foregroundStyle(store.selectedTransports.contains(transport) ? Color.pmindigo.n500 : Color.pmtext.secondary)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
              .contentShape(Rectangle())
              .opacity(store.isPro ? 1 : 0.5)
            }
            .buttonStyle(.plain)

            if transport != AvailableTransport.allCases.last {
              Divider()
                .padding(.leading, 48)
            }
          }
        }
        .adaptiveGlassCard()
      }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.briefingNotification)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        Text(LocalizedStrings.SettingsStrings.briefingNotificationDescription)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          HStack {
            Text(LocalizedStrings.SettingsStrings.briefingNotificationToggle)
              .font(.body)
              .foregroundStyle(store.isPro ? Color.pmtext.primary : Color.pmtext.secondary)

            Spacer()

            Toggle("", isOn: Binding(
              get: { store.isNotificationEnabled },
              set: { store.send(.view(.notificationToggled($0)), animation: .default) }
            ))
            .labelsHidden()
            .tint(Color.pmindigo.n500)
            .allowsHitTesting(store.isPro)
            .overlay {
              if !store.isPro {
                Color.clear
                  .contentShape(Rectangle())
                  .onTapGesture {
                    store.send(.view(.proFeatureTapped))
                  }
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)

          if store.isNotificationEnabled && store.isPro {
            Divider()
              .padding(.leading, 16)

            HStack {
              Text(LocalizedStrings.SettingsStrings.briefingNotificationTime)
                .font(.body)
                .foregroundStyle(Color.pmtext.primary)

              Spacer()

              Picker("", selection: Binding(
                get: { store.notificationHour ?? 8 },
                set: { store.send(.view(.notificationHourChanged($0))) }
              )) {
                ForEach(0..<24, id: \.self) { hour in
                  Text(hourLabel(for: hour))
                    .tag(hour)
                }
              }
              .pickerStyle(.menu)
              .tint(Color.pmindigo.n500)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
          }

          if store.isNotificationEnabled && store.isPro && !store.notificationAuthStatus.isGranted {
            Divider()
              .padding(.leading, 16)

            HStack(spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.pmwarning.n500)

              Text(LocalizedStrings.SettingsStrings.briefingNotificationPermissionRequired)
                .font(.caption)
                .foregroundStyle(Color.pmtext.secondary)

              Spacer()

              Button {
                store.send(.view(.notificationPermissionBannerTapped))
              } label: {
                Text(LocalizedStrings.Shared.goToSettings)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Color.pmindigo.n500)
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
          }
        }
        .adaptiveGlassCard()
        .opacity(store.isPro ? 1 : 0.5)
      }
    }

    private func hourLabel(for hour: Int) -> String {
      if hour == 0 {
        return "오전 12시"
      } else if hour < 12 {
        return "오전 \(hour)시"
      } else if hour == 12 {
        return "오후 12시"
      } else {
        return "오후 \(hour - 12)시"
      }
    }
  }
}
