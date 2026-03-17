//
//  ProOnboardingSetupView.swift
//  ProPlanFeature
//
//  Created by Claude on 2026-03-11.
//

import Clients
import ComposableArchitecture
import PromisoShared
import ResourceKit
import SwiftUI

// MARK: - Conflict Option Model

struct ConflictOption: Identifiable {
  let id: Int
  let label: String
  let description: String
}

// MARK: - Pro Onboarding Setup View

/// Pro 가입 후 초기 설정 워크스루 (PaywallView, RootView 양쪽에서 재사용)
struct ProOnboardingSetupView: View {
  @Bindable private var store: StoreOf<ProPlan.Feature>
  @State private var navigateForward: Bool = true

  init(store: StoreOf<ProPlan.Feature>) {
    self.store = store
  }

  var body: some View {
    VStack(spacing: 0) {
      onboardingProgressBar

      Group {
        switch store.onboardingStep {
        case 0: onboardingStep0
        case 1: onboardingStep1
        case 2: onboardingStep2
        default: EmptyView()
        }
      }
      .id(store.onboardingStep)
      .transition(.push(from: navigateForward ? .trailing : .leading))
      .animation(.easeInOut(duration: 0.3), value: store.onboardingStep)

      onboardingBottomBar
    }
    .auroraBackground()
    .toolbar(.hidden, for: .navigationBar)
    .interactiveDismissDisabled()
  }

  private var conflictOptions: [ConflictOption] {
    [
      .init(
        id: 0,
        label: LocalizedStrings.SettingsStrings.conflictDetectionOverlapOnly,
        description: LocalizedStrings.SettingsStrings.conflictDetectionOverlapOnlyHint
      ),
      .init(
        id: 15,
        label: conflictThresholdLabel(15),
        description: LocalizedStrings.SettingsStrings.conflictDetectionThresholdDescriptionMinutes(15)
      ),
      .init(
        id: 30,
        label: conflictThresholdLabel(30),
        description: LocalizedStrings.SettingsStrings.conflictDetectionThresholdDescriptionMinutes(30)
      ),
      .init(
        id: 60,
        label: conflictThresholdLabel(60),
        description: LocalizedStrings.SettingsStrings.conflictDetectionThresholdDescriptionHours(1)
      ),
    ]
  }

  // MARK: - Progress Bar

  @ViewBuilder
  private var onboardingProgressBar: some View {
    HStack(spacing: 8) {
      ForEach(0..<3) { step in
        Capsule()
          .fill(step <= store.onboardingStep
            ? LinearGradient(colors: [Color.pmaurora.purple, Color.pmaurora.pink], startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color.pmgray.n700.opacity(0.2), Color.pmgray.n700.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
          )
          .frame(height: 4)
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 8)
  }

  // MARK: - Step 0: Conflict Detection

  @ViewBuilder
  private var onboardingStep0: some View {
    ScrollView {
      VStack(spacing: 20) {
        VStack(spacing: 8) {
          Image(systemName: "calendar.badge.exclamationmark")
            .font(.system(size: 44))
            .foregroundStyle(Color.pmwarning.n500)

          Text(LocalizedStrings.SettingsStrings.conflictDetectionTitle)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text(LocalizedStrings.ProPlan.onboardingConflictSubtitle)
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 20)

        if store.isSettingUpDefaults {
          ProgressView()
        } else {
          conflictPreviewCard

          VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStrings.SettingsStrings.conflictDetectionThresholdSection)
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(Color.pmtext.primary)

            Text(LocalizedStrings.SettingsStrings.conflictDetectionThresholdHint)
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)

            VStack(spacing: 0) {
              ForEach(conflictOptions) { option in
                Button {
                  store.send(.view(.onboardingConflictChanged(option.id)))
                } label: {
                  HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                      Text(option.label)
                        .font(.body)
                        .foregroundStyle(Color.pmtext.primary)
                      Text(option.description)
                        .font(.caption)
                        .foregroundStyle(Color.pmtext.secondary)
                    }

                    Spacer()

                    if store.onboardingConflictThreshold == option.id {
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

                if option.id != conflictOptions.last?.id {
                  Divider()
                    .padding(.leading, 16)
                }
              }
            }
            .adaptiveGlassCard()
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 100)
    }
  }

  // MARK: - Conflict Preview

  @ViewBuilder
  private var conflictPreviewCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 14))
          .foregroundStyle(Color.pmwarning.n500)
        Text(LocalizedStrings.ProPlan.onboardingConflictDetected)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
      }

      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(LocalizedStrings.ProPlan.onboardingConflictExistingTitle)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
          Text(LocalizedStrings.ProPlan.onboardingConflictExistingTime)
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pmwarning.n500.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

        Image(systemName: "arrow.left.arrow.right")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)

        VStack(alignment: .leading, spacing: 4) {
          Text(LocalizedStrings.ProPlan.onboardingConflictNewTitle)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
          Text(LocalizedStrings.ProPlan.onboardingConflictNewTime)
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pmindigo.n500.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
      }

      HStack(spacing: 4) {
        Image(systemName: "clock.fill")
          .font(.system(size: 11))
        Text(LocalizedStrings.ProPlan.onboardingConflictOverlap)
          .font(.system(size: 12, weight: .medium))
      }
      .foregroundStyle(Color.pmwarning.n500)
    }
    .padding(16)
    .adaptiveGlassCard()
  }

  // MARK: - Step 1: Briefing

  @ViewBuilder
  private var onboardingStep1: some View {
    ScrollView {
      VStack(spacing: 20) {
        VStack(spacing: 8) {
          Image(systemName: "bell.badge.waveform")
            .font(.system(size: 44))
            .foregroundStyle(Color.pmaurora.purple)

          Text(LocalizedStrings.ProPlan.featureSmartBriefingTitle)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text(LocalizedStrings.ProPlan.onboardingBriefingSubtitle)
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 20)

        briefingPreviewCard

        VStack(alignment: .leading, spacing: 10) {
          Text(LocalizedStrings.SettingsStrings.briefingStyle)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)

          VStack(spacing: 0) {
            ForEach(BriefingStyle.allCases, id: \.rawValue) { style in
              Button {
                store.send(.view(.onboardingStyleChanged(style)))
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: briefingStyleIcon(style))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 20)

                  VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                      .font(.body)
                      .foregroundStyle(Color.pmtext.primary)
                    Text(style.description)
                      .font(.caption)
                      .foregroundStyle(Color.pmtext.secondary)
                  }

                  Spacer()

                  if store.onboardingBriefingStyle == style {
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

              if style != BriefingStyle.allCases.last {
                Divider()
                  .padding(.leading, 48)
              }
            }
          }
          .adaptiveGlassCard()
        }

        VStack(alignment: .leading, spacing: 10) {
          Text(LocalizedStrings.ProPlan.onboardingAlertAndTransport)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)

          VStack(spacing: 0) {
            HStack {
              HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                  .font(.system(size: 14))
                  .foregroundStyle(Color.pmindigo.n500)
                Text(LocalizedStrings.SettingsStrings.briefingNotification)
                  .font(.body)
                  .foregroundStyle(Color.pmtext.primary)
              }

              Spacer()

              Menu {
                ForEach(5..<24, id: \.self) { hour in
                  Button {
                    store.send(.view(.onboardingHourChanged(hour)))
                  } label: {
                    HStack {
                      Text(hourLabel(hour))
                      if store.onboardingBriefingHour == hour {
                        Image(systemName: "checkmark")
                      }
                    }
                  }
                }
              } label: {
                HStack(spacing: 4) {
                  Text(hourLabel(store.onboardingBriefingHour))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pmindigo.n500)
                  Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.pmtext.secondary)
                }
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.leading, 16)

            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 8) {
                Image(systemName: "car.fill")
                  .font(.system(size: 14))
                  .foregroundStyle(Color.pmindigo.n500)
                Text(LocalizedStrings.SettingsStrings.briefingTransport)
                  .font(.body)
                  .foregroundStyle(Color.pmtext.primary)
              }
              .padding(.horizontal, 16)
              .padding(.top, 14)

              ForEach(AvailableTransport.allCases, id: \.self) { transport in
                Button {
                  store.send(.view(.onboardingTransportToggled(transport)))
                } label: {
                  HStack(spacing: 12) {
                    Image(systemName: transport.iconName)
                      .font(.system(size: 14))
                      .foregroundStyle(Color.pmindigo.n500)
                      .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                      Text(transport.displayName)
                        .font(.body)
                        .foregroundStyle(Color.pmtext.primary)
                    }

                    Spacer()

                    Image(systemName: store.onboardingTransports.contains(transport) ? "checkmark.circle.fill" : "circle")
                      .font(.system(size: 20))
                      .foregroundStyle(store.onboardingTransports.contains(transport) ? Color.pmindigo.n500 : Color.pmtext.secondary)
                  }
                  .padding(.horizontal, 16)
                  .padding(.vertical, 10)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
              }
              .padding(.bottom, 6)
            }
          }
          .adaptiveGlassCard()
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 100)
    }
  }

  // MARK: - Briefing Preview

  @ViewBuilder
  private var briefingPreviewCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: "sparkles")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmaurora.purple)
        Text(LocalizedStrings.ProPlan.onboardingTodayBriefing)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
        Spacer()
        Text(LocalizedStrings.ProPlan.onboardingTodayBriefingTime)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
      }

      Divider()

      VStack(alignment: .leading, spacing: 6) {
        Text(LocalizedStrings.ProPlan.onboardingTodayBriefingMessage)
          .font(.system(size: 13))
          .foregroundStyle(Color.pmtext.primary)

        HStack(spacing: 12) {
          Label(LocalizedStrings.ProPlan.onboardingTodayBriefingWeather, systemImage: "sun.max.fill")
            .font(.system(size: 11))
            .symbolRenderingMode(.multicolor)
          Label(LocalizedStrings.ProPlan.onboardingTodayBriefingTransport, systemImage: "bus.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
          Label(LocalizedStrings.ProPlan.onboardingTodayBriefingDeparture, systemImage: "clock.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmaurora.purple)
        }
      }
    }
    .padding(16)
    .adaptiveGlassCard()
  }

  // MARK: - Step 2: Summary

  @ViewBuilder
  private var onboardingStep2: some View {
    ScrollView {
      VStack(spacing: 24) {
        VStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 56))
            .foregroundStyle(
              LinearGradient(
                colors: [Color.pmaurora.purple, Color.pmaurora.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )

          Text(LocalizedStrings.ProPlan.onboardingCompleteTitle)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text(LocalizedStrings.ProPlan.onboardingCompleteSubtitle)
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
        }
        .padding(.top, 40)

        VStack(spacing: 0) {
          summaryRow(
            icon: "calendar.badge.exclamationmark",
            iconColor: Color.pmwarning.n500,
            title: LocalizedStrings.SettingsStrings.conflictDetectionTitle,
            value: conflictThresholdLabel(store.onboardingConflictThreshold)
          )
          Divider().padding(.leading, 48)
          summaryRow(
            icon: briefingStyleIcon(store.onboardingBriefingStyle),
            iconColor: Color.pmindigo.n500,
            title: LocalizedStrings.SettingsStrings.briefingStyle,
            value: store.onboardingBriefingStyle.displayName
          )
          Divider().padding(.leading, 48)
          summaryRow(
            icon: "bell.fill",
            iconColor: Color.pmaurora.purple,
            title: LocalizedStrings.SettingsStrings.briefingNotification,
            value: hourLabel(store.onboardingBriefingHour)
          )
          Divider().padding(.leading, 48)
          summaryRow(
            icon: "car.fill",
            iconColor: Color.pmindigo.n500,
            title: LocalizedStrings.SettingsStrings.briefingTransport,
            value: store.onboardingTransports.sorted(by: { $0.rawValue < $1.rawValue }).map(\.displayName).joined(separator: ", ")
          )
        }
        .adaptiveGlassCard()
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 100)
    }
  }

  // MARK: - Bottom Bar

  @ViewBuilder
  private var onboardingBottomBar: some View {
    HStack(spacing: 12) {
      if store.onboardingStep > 0 {
        Button {
          navigateForward = false
          store.send(.view(.onboardingPreviousStep))
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
            .frame(width: 52, height: 52)
            .background(Color.pmgray.n700.opacity(0.15), in: Circle())
            .contentShape(Circle())
        }
      }

      Button {
        navigateForward = true
        if store.onboardingStep < 2 {
          store.send(.view(.onboardingNextStep))
        } else {
          store.send(.view(.proOnboardingCompleted))
        }
      } label: {
        HStack {
          Text(store.onboardingStep == 2 ? LocalizedStrings.ProPlan.startButton : LocalizedStrings.Common.next)
            .font(.headline)
            .foregroundStyle(.white)

          Spacer()

          Image(systemName: store.onboardingStep == 2 ? "checkmark" : "arrow.right")
            .font(.headline)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
          LinearGradient(
            colors: [Color.pmaurora.purple, Color.pmaurora.pink],
            startPoint: .leading,
            endPoint: .trailing
          ),
          in: RoundedRectangle(cornerRadius: 16)
        )
        .contentShape(Rectangle())
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 16)
    .padding(.top, 8)
    .background(
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: Color(.systemBackground).opacity(0.8), location: 0.3),
          .init(color: Color(.systemBackground), location: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 100)
      .frame(maxHeight: .infinity, alignment: .bottom)
      .ignoresSafeArea()
    )
  }

  // MARK: - Helpers

  private func summaryRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 28, height: 28)
        .background(iconColor, in: Circle())

      Text(title)
        .font(.body)
        .foregroundStyle(Color.pmtext.primary)

      Spacer()

      Text(value)
        .font(.body)
        .foregroundStyle(Color.pmindigo.n500)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private func briefingStyleIcon(_ style: BriefingStyle) -> String {
    switch style {
    case .friendly: return "face.smiling"
    case .humorous: return "theatermasks"
    case .concise: return "text.alignleft"
    case .motivational: return "flame"
    case .calm: return "leaf"
    }
  }

  private func conflictThresholdLabel(_ minutes: Int) -> String {
    guard minutes > 0 else { return LocalizedStrings.SettingsStrings.conflictDetectionOverlapOnly }
    if minutes % 60 == 0 {
      return String(localized: "proPlan.duration.hours", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes / 60)")
    }
    return String(localized: "proPlan.duration.minutes", bundle: LocalizedStrings.bundle)
      .replacingOccurrences(of: "%lld", with: "\(minutes)")
  }

  private func hourLabel(_ hour: Int) -> String {
    let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
    return date.formatted(
      Date.FormatStyle()
        .locale(LocaleManager.appLocale)
        .hour(.defaultDigits(amPM: .wide))
    )
  }
}
