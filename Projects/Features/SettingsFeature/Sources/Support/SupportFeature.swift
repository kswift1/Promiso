//
//  SupportFeature.swift
//  SettingsFeature
//
//  Created by Claude on 2026-02-04.
//

import Clients
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
      case featureRequestTapped
      case kakaoChannelTapped
      case rateAppTapped
      case toastDismissed
    }

    public enum Internal: Equatable, Sendable {
      case mailOpenResult(Bool)
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
          return openMailClient(
            subject: Strings.BugReport.subject,
            bodyBuilder: Strings.BugReport.body
          )

        case .view(.featureRequestTapped):
          return openMailClient(
            subject: Strings.FeatureRequest.subject,
            bodyBuilder: Strings.FeatureRequest.body
          )

        case .view(.kakaoChannelTapped):
          return .run { _ in
            await hapticFeedback.selection()
            if let appURL = URL(string: "kakaoplus://plusfriend/chat/_wxgnVX") {
              let opened = await openURL(appURL)
              if !opened, let webURL = URL(string: "https://pf.kakao.com/_wxgnVX") {
                await openURL(webURL)
              }
            }
          }

        case .view(.rateAppTapped):
          return .run { _ in
            await hapticFeedback.selection()
            await openURL(AppConstants.appStoreURL)
          }

        case .view(.toastDismissed):
          state.toastMessage = nil
          return .none

        case .internal(.mailOpenResult(let opened)):
          if !opened {
            state.toastMessage = ToastMessage(type: .error, title: LocalizedStrings.SettingsStrings.mailAppUnavailable, position: .bottom)
          }
          return .none

        case .delegate:
          return .none
        }
      }
    }

    // MARK: - Helpers

    private func openMailClient(
      subject: String,
      bodyBuilder: @escaping @Sendable (String, String, String, String) -> String
    ) -> Effect<Action> {
      .run { [hapticFeedback, openURL] send in
        await hapticFeedback.selection()
        let osVersion = await MainActor.run { UIDevice.current.systemVersion }
        let body = bodyBuilder(
          AppConstants.App.version,
          AppConstants.App.buildNumber,
          Self.deviceModel(),
          osVersion
        )

        let email = AppConstants.App.supportEmail
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
          let opened = await openURL(url)
          await send(.internal(.mailOpenResult(opened)))
        } else {
          await send(.internal(.mailOpenResult(false)))
        }
      }
    }

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

            Divider()
              .background(Color.white.opacity(0.12))

            // 기능 건의
            Button {
              store.send(.view(.featureRequestTapped))
            } label: {
              HStack(spacing: 16) {
                Image(systemName: "lightbulb.fill")
                  .font(.body)
                  .foregroundStyle(Color.pmindigo.n500)
                  .frame(width: 24, height: 24)

                Text(LocalizedStrings.SettingsStrings.featureRequest)
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

            Divider()
              .background(Color.white.opacity(0.12))

            // 카카오톡 채널
            Button {
              store.send(.view(.kakaoChannelTapped))
            } label: {
              HStack(spacing: 16) {
                Image(systemName: "bubble.left.fill")
                  .font(.body)
                  .foregroundStyle(Color.pmindigo.n500)
                  .frame(width: 24, height: 24)

                Text(LocalizedStrings.SettingsStrings.kakaoChannel)
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

            Divider()
              .background(Color.white.opacity(0.12))

            // 앱 평가하기
            Button {
              store.send(.view(.rateAppTapped))
            } label: {
              HStack(spacing: 16) {
                Image(systemName: "star.fill")
                  .font(.body)
                  .foregroundStyle(Color.pmindigo.n500)
                  .frame(width: 24, height: 24)

                Text(LocalizedStrings.SettingsStrings.rateApp)
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

    enum FeatureRequest {
      static let subject = "[\(AppConstants.App.name)] 기능 건의"

      static func body(version: String, build: String, device: String, osVersion: String) -> String {
        """
        보내주신 의견은 적극 검토하여 반영하도록 노력하겠습니다.
        아래에 원하시는 기능을 자유롭게 작성해주세요.


        ---
        앱 버전: \(version) (\(build))
        기기: \(device)
        iOS: \(osVersion)
        """
      }
    }
  }
}
