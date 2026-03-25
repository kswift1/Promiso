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
import SharedFeature
import SwiftUI

private func localizedPreviewTime(hour: Int, minute: Int) -> String {
  var components = DateComponents()
  components.calendar = .autoupdatingCurrent
  components.timeZone = .autoupdatingCurrent
  components.year = 2026
  components.month = 1
  components.day = 1
  components.hour = hour
  components.minute = minute

  return (components.date ?? Date()).formatted(date: .omitted, time: .shortened)
}

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
      Group {
        switch store.onboardingStep {
        case 0: onboardingStep0
        case 1: onboardingStep1
        case 2: onboardingStep2
        case 3: onboardingStep3
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
    .sheet(item: $store.scope(state: \.locationPicker, action: \.locationPicker)) { locationStore in
      NavigationStack {
        LocationPicker.RootView(store: locationStore)
      }
    }
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
        label: LocalizedStrings.DateFormat.durationMinutes(15),
        description: LocalizedStrings.SettingsStrings.conflictDetectionThresholdDescriptionMinutes(15)
      ),
      .init(
        id: 30,
        label: LocalizedStrings.DateFormat.durationMinutes(30),
        description: LocalizedStrings.SettingsStrings.conflictDetectionThresholdDescriptionMinutes(30)
      ),
      .init(
        id: 60,
        label: LocalizedStrings.DateFormat.durationHours(1),
        description: LocalizedStrings.SettingsStrings.conflictDetectionThresholdDescriptionHours(1)
      ),
    ]
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

          Text(LocalizedStrings.ProPlan.onboardingConflictTitle)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text(LocalizedStrings.ProPlan.onboardingConflictSubtitleNew)
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
            .staticGlassCard()
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
      conflictPreviewBadgeCard
      conflictPreviewTimeline
    }
  }

  @ViewBuilder
  private var conflictPreviewBadgeCard: some View {
    VStack(alignment: .leading, spacing: 6) {
      // PRO badge
      HStack(spacing: 2) {
        Image(systemName: "sparkles")
          .font(.system(size: 7, weight: .bold))
        Text("PRO")
          .font(.system(size: 7, weight: .heavy))
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(
        LinearGradient(
          colors: [Color.pmindigo.n500, Color.pmpurple.n500],
          startPoint: .leading,
          endPoint: .trailing
        ),
        in: Capsule()
      )

      // Weather row
      HStack(spacing: 6) {
        Image(systemName: "cloud.rain.fill")
          .symbolRenderingMode(.multicolor)
          .font(.system(size: 11))
          .frame(width: 20, height: 20)
          .background(
            Circle()
              .fill(Color.cyan.opacity(0.12))
          )

        Text("8°")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)

        Text(LocalizedStrings.ProPlan.mockRainAlert)
          .font(.system(size: 11))
          .foregroundStyle(Color.pmtext.secondary)
          .lineLimit(1)

        Spacer(minLength: 0)

        Image(systemName: "info.circle")
          .font(.system(size: 10))
          .foregroundStyle(Color.pmgray.n400)
      }

      // Conflict summary row
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmwarning.n500)

        Text(LocalizedStrings.ProPlan.mockConflictTitle)
          .font(.system(size: 11))
          .foregroundStyle(Color.pmtext.primary)
          .lineLimit(1)

        Spacer(minLength: 0)

        Image(systemName: "info.circle")
          .font(.system(size: 11))
          .foregroundStyle(Color.pmgray.n400)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .staticGlassCard()
  }

  @ViewBuilder
  private var conflictPreviewTimeline: some View {
    HStack(alignment: .top, spacing: 4) {
      // Time labels
      VStack(alignment: .trailing, spacing: 0) {
        Text("1:00")
          .font(.system(size: 8, weight: .medium, design: .rounded))
          .foregroundStyle(Color.pmtext.secondary)
        Spacer()
        Text("1:30")
          .font(.system(size: 8, weight: .medium, design: .rounded))
          .foregroundStyle(Color.pmwarning.n600)
        Spacer()
        Text("2:00")
          .font(.system(size: 8, weight: .medium, design: .rounded))
          .foregroundStyle(Color.pmtext.secondary)
        Spacer()
        Text("3:00")
          .font(.system(size: 8, weight: .medium, design: .rounded))
          .foregroundStyle(Color.pmtext.secondary)
      }
      .frame(width: 26, height: 64)

      // Team meeting block (1:00-2:00)
      VStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.pmindigo.n500.opacity(0.15))
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .strokeBorder(Color.pmindigo.n500.opacity(0.4), lineWidth: 1)
          )
          .overlay(
            Text(verbatim: "📌 \(LocalizedStrings.ProPlan.mockConflictExistingTitle)")
              .font(.system(size: 9, weight: .medium))
              .foregroundStyle(Color.pmindigo.n500)
          )
          .frame(height: 32)
        Spacer(minLength: 0)
      }
      .frame(height: 64)

      // Lunch block (1:30-3:00)
      VStack(spacing: 0) {
        Spacer().frame(height: 16)
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.pmwarning.n600.opacity(0.12))
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .strokeBorder(Color.pmwarning.n600.opacity(0.4), lineWidth: 1)
          )
          .overlay(
            Text(verbatim: "🍽️ \(LocalizedStrings.ProPlan.mockConflictNewTitle)")
              .font(.system(size: 9, weight: .medium))
              .foregroundStyle(Color.pmwarning.n600)
          )
          .frame(height: 48)
      }
      .frame(height: 64)
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(.systemBackground).opacity(0.5))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(Color.pmgray.n200.opacity(0.3), lineWidth: 1)
    )
  }

  // MARK: - Step 1: Briefing Settings (알림시간 + 기본위치)

  @ViewBuilder
  private var onboardingStep1: some View {
    ScrollView {
      VStack(spacing: 20) {
        VStack(spacing: 8) {
          Image(systemName: "bell.badge.waveform")
            .font(.system(size: 44))
            .foregroundStyle(Color.pmaurora.purple)

          Text(LocalizedStrings.ProPlan.onboardingBriefingSettingsTitle)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text(LocalizedStrings.ProPlan.onboardingBriefingSettingsSubtitle)
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 20)

        briefingPreviewCard

        VStack(alignment: .leading, spacing: 10) {
          Text(LocalizedStrings.SettingsStrings.briefingNotification)
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
                ForEach(0..<24, id: \.self) { hour in
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
          }
          .staticGlassCard()
        }

        VStack(alignment: .leading, spacing: 10) {
          Text(LocalizedStrings.SettingsStrings.briefingDefaultLocation)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)

          Text(LocalizedStrings.SettingsStrings.briefingDefaultLocationDescription)
            .font(.system(size: 12))
            .foregroundStyle(Color.pmtext.secondary)

          VStack(spacing: 0) {
            if let location = store.onboardingDefaultLocation {
              HStack(spacing: 12) {
                HStack(spacing: 12) {
                  Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.pmindigo.n500)

                  VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                      .font(.subheadline.weight(.medium))
                      .foregroundStyle(Color.pmtext.primary)

                    if let address = location.address {
                      Text(address)
                        .font(.caption)
                        .foregroundStyle(Color.pmtext.secondary)
                        .lineLimit(1)
                    }
                  }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                  store.send(.view(.onboardingDefaultLocationTapped))
                }

                Spacer()

                Button {
                  store.send(.view(.onboardingRemoveDefaultLocation))
                } label: {
                  Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.pmtext.secondary)
                }
                .buttonStyle(.plain)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
            } else {
              Button {
                store.send(.view(.onboardingDefaultLocationTapped))
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.pmindigo.n500)

                  Text(LocalizedStrings.SettingsStrings.briefingDefaultLocationPlaceholder)
                    .font(.subheadline)
                    .foregroundStyle(Color.pmtext.secondary)

                  Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
            }
          }
          .staticGlassCard()
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 100)
    }
  }

  // MARK: - Step 2: Briefing Style (교통수단 + 스타일)

  @ViewBuilder
  private var onboardingStep2: some View {
    ScrollView {
      VStack(spacing: 20) {
        VStack(spacing: 8) {
          Image(systemName: "paintbrush.pointed")
            .font(.system(size: 44))
            .foregroundStyle(Color.pmaurora.purple)

          Text(LocalizedStrings.ProPlan.onboardingBriefingStyleTitle)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text(LocalizedStrings.ProPlan.onboardingBriefingStyleSubtitle)
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 20)

        VStack(alignment: .leading, spacing: 10) {
          VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 4) {
                Text(LocalizedStrings.SettingsStrings.briefingTransport)
                  .font(.body)
                  .foregroundStyle(Color.pmtext.primary)
                Text(LocalizedStrings.ProPlan.onboardingMultipleSelectHint)
                  .font(.caption)
                  .foregroundStyle(Color.pmtext.secondary)
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
          .staticGlassCard()
        }

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
          .staticGlassCard()
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
      // Header
      HStack(spacing: 6) {
        HStack(spacing: 2) {
          Image(systemName: "sparkles")
            .font(.system(size: 8, weight: .bold))
          Text("PRO")
            .font(.system(size: 8, weight: .heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
          LinearGradient(
            colors: [Color.pmindigo.n500, Color.pmpurple.n500],
            startPoint: .leading,
            endPoint: .trailing
          ),
          in: Capsule()
        )

        Text(LocalizedStrings.ProPlan.onboardingTodayBriefing)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)

        Spacer()
      }

      Divider()

      // Briefing body
      Text(LocalizedStrings.ProPlan.previewBriefingBody)
        .font(.system(size: 12))
        .foregroundStyle(Color.pmtext.primary)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)

      Divider()

      // Custom option tags
      HStack(spacing: 6) {
        customTag(icon: "face.smiling", text: BriefingStyle.humorous.displayName)
        customTag(icon: "car.fill", text: LocalizedStrings.ProPlan.previewTransportIncluded(AvailableTransport.car.displayName))
        customTag(icon: "clock", text: LocalizedStrings.ProPlan.onboardingTodayBriefingTime)
      }
    }
    .padding(16)
    .staticGlassCard()
  }

  private func customTag(icon: String, text: String) -> some View {
    HStack(spacing: 3) {
      Image(systemName: icon)
        .font(.system(size: 8))
      Text(text)
        .font(.system(size: 9, weight: .medium))
    }
    .foregroundStyle(Color.pmindigo.n500)
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(Color.pmindigo.n500.opacity(0.08), in: Capsule())
  }

  // MARK: - Step 3: Summary

  @ViewBuilder
  private var onboardingStep3: some View {
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
            value: store.onboardingConflictThreshold == 0
              ? LocalizedStrings.SettingsStrings.conflictDetectionOverlapOnly
              : store.onboardingConflictThreshold % 60 == 0
                ? LocalizedStrings.DateFormat.durationHours(store.onboardingConflictThreshold / 60)
                : LocalizedStrings.DateFormat.durationMinutes(store.onboardingConflictThreshold)
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
          if let location = store.onboardingDefaultLocation {
            Divider().padding(.leading, 48)
            summaryRow(
              icon: "mappin.circle.fill",
              iconColor: Color.pmindigo.n500,
              title: LocalizedStrings.SettingsStrings.briefingDefaultLocation,
              value: location.name
            )
          }
        }
        .staticGlassCard()
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
        if store.onboardingStep < 3 {
          store.send(.view(.onboardingNextStep))
        } else {
          store.send(.view(.proOnboardingCompleted))
        }
      } label: {
        HStack {
          Text(store.onboardingStep == 3 ? LocalizedStrings.ProPlan.startButton : LocalizedStrings.Common.next)
            .font(.headline)
            .foregroundStyle(.white)

          Spacer()

          Image(systemName: store.onboardingStep == 3 ? "checkmark" : "arrow.right")
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
    .padding(.top, 12)
    .padding(.bottom, 8)
    .background(
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: Color(.systemBackground).opacity(0.95), location: 0.15),
          .init(color: Color(.systemBackground), location: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
    )
    .safeAreaPadding(.bottom)
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

  private func hourLabel(_ hour: Int) -> String {
    let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
    return date.formatted(
      Date.FormatStyle()
        .locale(LocaleManager.appLocale)
        .hour(.defaultDigits(amPM: .wide))
    )
  }
}

// MARK: - Previews

#Preview("Step 0 - 충돌 감지") {
  ProOnboardingSetupView(
    store: Store(
      initialState: ProPlan.Feature.State()
    ) {
      ProPlan.Feature()
    } withDependencies: {
      $0.subscriptionClient = .previewValue
    }
  )
  .environment(\.locale, Locale(identifier: "ko"))
}

#Preview("Step 1 - 브리핑설정") {
  ProOnboardingSetupView(
    store: Store(
      initialState: ProPlan.Feature.State()
    ) {
      ProPlan.Feature()
    } withDependencies: {
      $0.subscriptionClient = .previewValue
    }
  )
  .environment(\.locale, Locale(identifier: "ko"))
}

#Preview("Step 2 - 브리핑스타일") {
  ProOnboardingSetupView(
    store: Store(
      initialState: ProPlan.Feature.State()
    ) {
      ProPlan.Feature()
    } withDependencies: {
      $0.subscriptionClient = .previewValue
    }
  )
  .environment(\.locale, Locale(identifier: "ko"))
}

#Preview("Step 3 - 설정 완료") {
  ProOnboardingSetupView(
    store: Store(
      initialState: ProPlan.Feature.State()
    ) {
      ProPlan.Feature()
    } withDependencies: {
      $0.subscriptionClient = .previewValue
    }
  )
  .environment(\.locale, Locale(identifier: "ko"))
}
