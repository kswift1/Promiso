//
//  SupportFeature.swift
//  SettingsFeature
//
//  Created by Claude on 2026-02-04.
//

import ComposableArchitecture
import PromisoShared
import SwiftUI

// MARK: - Feature Namespace

/// Support Feature 컴포넌트를 위한 Namespace
public enum Support {}

// MARK: - Feature Implementation

extension Support {

  @Reducer
  public struct Feature {

    // MARK: - Dependencies

    @Dependency(\.hapticFeedback) private var hapticFeedback
    @Dependency(\.openURL) private var openURL

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
      var toastMessage: ToastMessage?
      public init() {}
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case faqTapped
      case bugReportTapped
      case toastDismissed
    }

    public enum Internal: Equatable, Sendable {
      case bugReportOpenResult(Bool)
    }

    public enum Delegate: Equatable, Sendable {
      case navigateToFAQ
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.onAppear):
          return .none

        case .view(.faqTapped):
          return .run { send in
            await hapticFeedback.selection()
            await send(.delegate(.navigateToFAQ))
          }

        case .view(.bugReportTapped):
          return .run { send in
            await hapticFeedback.selection()
            // 이메일 앱 열기
            let email = AppConstants.App.supportEmail
            let subject = Strings.BugReport.subject
            let osVersion = await MainActor.run { UIDevice.current.systemVersion }
            let body = Strings.BugReport.body(
              version: AppConstants.App.version,
              build: AppConstants.App.buildNumber,
              device: Self.deviceModel(),
              osVersion: osVersion
            )

            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

            if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
              let opened = await openURL(url)
              await send(.internal(.bugReportOpenResult(opened)))
            } else {
              await send(.internal(.bugReportOpenResult(false)))
            }
          }

        case .view(.toastDismissed):
          state.toastMessage = nil
          return .none

        case .internal(.bugReportOpenResult):
          return .none

        case .delegate:
          return .none
        }
      }
    }

    // MARK: - Helpers

    private static func deviceModel() -> String {
      var systemInfo = utsname()
      uname(&systemInfo)
      let machineMirror = Mirror(reflecting: systemInfo.machine)
      let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
      }
      return identifier
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    private let store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          VStack(spacing: 0) {
            // FAQ
            Button {
              store.send(.view(.faqTapped))
            } label: {
              HStack(spacing: 16) {
                Image(systemName: "questionmark.circle.fill")
                  .font(.body)
                  .foregroundStyle(Color.pmindigo.n500)
                  .frame(width: 24, height: 24)

                Text(LocalizedStrings.SettingsStrings.faq)
                  .font(.body)
                  .foregroundStyle(Color.pmtext.primary)

                Spacer()

                Image(systemName: "chevron.right")
                  .font(.caption)
                  .foregroundStyle(Color.pmgray.n400)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
              .background(Color.white.opacity(0.12))

            // 오류 제보
            Button {
              store.send(.view(.bugReportTapped))
            } label: {
              HStack(spacing: 16) {
                Image(systemName: "envelope.fill")
                  .font(.body)
                  .foregroundStyle(Color.pmindigo.n500)
                  .frame(width: 24, height: 24)

                Text(LocalizedStrings.SettingsStrings.bugReport)
                  .font(.body)
                  .foregroundStyle(Color.pmtext.primary)

                Spacer()

                Image(systemName: "arrow.up.forward")
                  .font(.caption)
                  .foregroundStyle(Color.pmgray.n400)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
          .adaptiveGlassCard()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.supportTitle)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
      .toast(Binding(
        get: { store.toastMessage },
        set: { _ in store.send(.view(.toastDismissed)) }
      ))
    }
  }

  // MARK: - Strings

  private enum Strings {
    enum BugReport {
      static let subject = "[\(AppConstants.App.name)] 오류 제보"

      static func body(version: String, build: String, device: String, osVersion: String) -> String {
        """

        ---
        앱 버전: \(version) (\(build))
        기기: \(device)
        iOS: \(osVersion)
        """
      }
    }
  }
}
