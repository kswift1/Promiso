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

  static let allOptions: [ConflictOption] = [
    .init(id: 0, label: "겹칠 때만", description: "시간이 겹치는 약속만 감지"),
    .init(id: 15, label: "15분", description: "15분 이내 간격도 감지"),
    .init(id: 30, label: "30분", description: "30분 이내 간격도 감지"),
    .init(id: 60, label: "1시간", description: "1시간 이내 간격도 감지"),
  ]
}

// MARK: - Pro Onboarding Setup View

/// Pro 가입 후 초기 설정 워크스루 (PaywallView, RootView 양쪽에서 재사용)
struct ProOnboardingSetupView: View {
  @Bindable private var store: StoreOf<ProPlan.Feature>

  init(store: StoreOf<ProPlan.Feature>) {
    self.store = store
  }

  var body: some View {
    VStack(spacing: 0) {
      onboardingProgressBar

      TabView(selection: Binding(
        get: { store.onboardingStep },
        set: { _ in }
      )) {
        onboardingStep0.tag(0)
        onboardingStep1.tag(1)
        onboardingStep2.tag(2)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .animation(.easeInOut(duration: 0.3), value: store.onboardingStep)

      onboardingBottomBar
    }
    .auroraBackground()
    .toolbar(.hidden, for: .navigationBar)
    .interactiveDismissDisabled()
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

          Text("일정 충돌 감지")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text("약속을 잡을 때 겹치는 일정이 있으면\n미리 알려드려요")
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
            Text("감지 기준 설정")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(Color.pmtext.primary)

            Text("약속 사이 여유 시간이 설정값보다 짧으면 충돌로 감지해요")
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)

            VStack(spacing: 0) {
              ForEach(ConflictOption.allOptions) { option in
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

                if option.id != ConflictOption.allOptions.last?.id {
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
        Text("일정 충돌이 감지되었어요")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
      }

      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("팀 회의")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
          Text("오후 1:00 - 2:00")
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
          Text("점심 약속")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
          Text("오후 1:30 - 3:00")
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
        Text("30분 겹침")
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

          Text("스마트 브리핑")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text("매일 아침, 오늘의 약속 정보를\n한눈에 브리핑해드려요")
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 20)

        briefingPreviewCard

        VStack(alignment: .leading, spacing: 10) {
          Text("브리핑 스타일")
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
          Text("알림 및 이동수단")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)

          VStack(spacing: 0) {
            HStack {
              HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                  .font(.system(size: 14))
                  .foregroundStyle(Color.pmindigo.n500)
                Text("브리핑 알림")
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
                Text("이용 교통수단")
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
        Text("오늘의 브리핑")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
        Spacer()
        Text("오전 8시")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
      }

      Divider()

      VStack(alignment: .leading, spacing: 6) {
        Text("오후 2시에 강남역 카페에서 약속이 있어요")
          .font(.system(size: 13))
          .foregroundStyle(Color.pmtext.primary)

        HStack(spacing: 12) {
          Label("22° 맑음", systemImage: "sun.max.fill")
            .font(.system(size: 11))
            .symbolRenderingMode(.multicolor)
          Label("대중교통 35분", systemImage: "bus.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
          Label("1:20 출발", systemImage: "clock.fill")
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

          Text("설정이 완료되었어요!")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text("설정은 언제든 변경할 수 있어요")
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
        }
        .padding(.top, 40)

        VStack(spacing: 0) {
          summaryRow(
            icon: "calendar.badge.exclamationmark",
            iconColor: Color.pmwarning.n500,
            title: "일정 충돌 감지",
            value: store.onboardingConflictThreshold == 0 ? "겹칠 때만" : "\(store.onboardingConflictThreshold)분"
          )
          Divider().padding(.leading, 48)
          summaryRow(
            icon: briefingStyleIcon(store.onboardingBriefingStyle),
            iconColor: Color.pmindigo.n500,
            title: "브리핑 스타일",
            value: store.onboardingBriefingStyle.displayName
          )
          Divider().padding(.leading, 48)
          summaryRow(
            icon: "bell.fill",
            iconColor: Color.pmaurora.purple,
            title: "브리핑 알림",
            value: hourLabel(store.onboardingBriefingHour)
          )
          Divider().padding(.leading, 48)
          summaryRow(
            icon: "car.fill",
            iconColor: Color.pmindigo.n500,
            title: "이용 교통수단",
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
        if store.onboardingStep < 2 {
          store.send(.view(.onboardingNextStep))
        } else {
          store.send(.view(.proOnboardingCompleted))
        }
      } label: {
        HStack {
          Text(store.onboardingStep == 2 ? "시작하기" : "다음")
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

  private func hourLabel(_ hour: Int) -> String {
    let period = hour < 12 ? "오전" : "오후"
    let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
    return "\(period) \(displayHour)시"
  }
}
