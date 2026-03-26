import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared
import ResourceKit
import PhotosUI

extension EditSchedule {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @FocusState private var focusedField: FocusedField?
    @State private var isMinusPressed = false
    @State private var isPlusPressed = false
    @State private var customTrackingMinutesText = ""
    @State private var isCustomTrackingMinutes = false

    enum FocusedField {
      case title, description, trackingMinutes
    }

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            // 제목 & 이모지 & 시작 시간 섹션
            essentialSection

            // 종료 시간 섹션
            endDateSection

            // 장소 섹션
            locationSection

            // 최소 참가 인원 섹션
            minimumParticipantsSection

            // 실시간 공유 섹션
            realtimeShareSection

            // 설명 섹션
            descriptionSection

            // 사진 첨부
            ImageAttachmentSection(
              existingImageUrls: store.editedSchedule.imageUrls.filter { !store.removedImageUrls.contains($0) },
              localImages: store.localImageData,
              isUploading: store.isUploadingImages,
              onPhotosSelected: { items in
                store.send(.view(.photosSelected(items)))
              },
              onRemoveExisting: { index in
                store.send(.view(.removeExistingImage(index)))
              },
              onRemoveLocal: { index in
                store.send(.view(.removeLocalImage(index)))
              }
            )
          }
          .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(LocalizedStrings.Shared.editScheduleTitle)
        .navigationBarTitleDisplayMode(.inline)
        .auroraBackground()
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(LocalizedStrings.Common.cancel) {
              store.send(.view(.cancelTapped))
            }
          }

          ToolbarItem(placement: .confirmationAction) {
            if store.isUpdating {
              ProgressView()
            } else {
              Button(LocalizedStrings.Common.modify) {
                store.send(.view(.saveTapped))
              }
              .fontWeight(.semibold)
              .disabled(!store.canSave)
            }
          }
        }
        .alert(
          LocalizedStrings.Shared.editFailed,
          isPresented: Binding(
            get: { store.updateError != nil },
            set: { if !$0 { store.send(.view(.clearError)) } }
          )
        ) {
          Button(LocalizedStrings.Common.confirm, role: .cancel) {
            store.send(.view(.clearError))
          }
        } message: {
          if let error = store.updateError {
            Text(error.localizedMessage)
          }
        }
        .sheet(item: $store.scope(state: \.locationPicker, action: \.locationPicker)) { pickerStore in
          LocationPicker.RootView(store: pickerStore)
        }
      }
    }

    // MARK: - Essential Section

    private var essentialSection: some View {
      VStack(spacing: 0) {
        // 제목 + 이모지
        VStack(alignment: .trailing, spacing: 4) {
          HStack(spacing: 12) {
            Text(store.editedSchedule.displayEmoji)
              .font(.system(size: 28))
              .frame(width: 40, height: 40)

            TextField(LocalizedStrings.Shared.scheduleTitlePlaceholder, text: Binding(
              get: { store.editedSchedule.title },
              set: { store.send(.view(.setTitle($0))) }
            ))
            .focused($focusedField, equals: .title)
            .font(.system(size: 18, weight: .medium))
            .textFieldStyle(.plain)
            .keyboardDismissToolbar()
          }

          Text("\(store.editedSchedule.title.count)/30")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .padding(12)

        Divider()
          .background(Color.white.opacity(0.12))

        // 시작 시간
        HStack {
          Image(systemName: "clock")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24)

          Text(LocalizedStrings.Common.start)
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)

          Spacer()

          DatePicker(
            "",
            selection: Binding(
              get: { store.editedSchedule.startAt },
              set: { store.send(.view(.setStartDate($0))) }
            ),
            in: Date()...,
            displayedComponents: [.date, .hourAndMinute]
          )
          .labelsHidden()
          .tint(Color.pmindigo.n500)
          .environment(\.locale, LocaleManager.appLocale)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
      .adaptiveGlassCard()
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 4) {
          Text(LocalizedStrings.Schedule.description)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Text(LocalizedStrings.Shared.optional)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }

        DescriptionBlockEditor(
          blocks: Binding(
            get: { store.editedSchedule.descriptionBlocks },
            set: { store.send(.view(.setDescriptionBlocks($0))) }
          )
        )
        .padding(16)
        .adaptiveGlassCard()
      }
    }

    // MARK: - Location Section

    @ViewBuilder
    private var locationSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 4) {
          Text(LocalizedStrings.Common.location)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Text(LocalizedStrings.Shared.optional)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }

        if let location = store.editedSchedule.location {
          VStack(spacing: 12) {
            // 장소 정보 (탭하여 변경)
            HStack(spacing: 12) {
              Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.pmindigo.n500)

              VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                  .font(.system(size: 15, weight: .medium))
                  .foregroundStyle(.primary)

                if let address = location.address {
                  Text(address)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
              }

              Spacer()

              Button {
                store.send(.view(.removeLocation))
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(Color.pmgray.n400)
              }
              .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture {
              store.send(.view(.locationTapped))
            }

            // 지도 프리뷰
            if let latitude = location.latitude,
               let longitude = location.longitude {
              KakaoMiniMapView(
                latitude: latitude,
                longitude: longitude,
                zoomLevel: 16
              )
              .frame(height: 160)
              .clipShape(RoundedRectangle(cornerRadius: 12))
            }
          }
        } else {
          Button {
            store.send(.view(.locationTapped))
          } label: {
            HStack {
              Image(systemName: "mappin")
                .font(.body)
                .foregroundColor(Color.pmindigo.n500)

              Text(LocalizedStrings.Shared.addLocation)
                .font(.system(size: 15))
                .foregroundStyle(.primary)

              Spacer()

              Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .padding(16)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }
      }
    }

    // MARK: - End Date Section

    @ViewBuilder
    private var endDateSection: some View {
      VStack(spacing: 0) {
        HStack {
          Image(systemName: "clock.badge.checkmark")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24)

          Text(LocalizedStrings.Common.endTime)
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)

          Spacer()

          Toggle("", isOn: Binding(
            get: { store.useEndTime },
            set: { _ in store.send(.view(.toggleUseEndTime), animation: .default) }
          ))
          .labelsHidden()
          .tint(Color.pmindigo.n500)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        if store.useEndTime {
          Divider()
            .background(Color.white.opacity(0.12))

          HStack {
            if let endAt = store.editedSchedule.endAt {
              Text(store.editedSchedule.startAt.durationText(
                to: endAt,
                prefix: LocalizedStrings.CreateSchedule.totalDurationPrefix
              ))
                .font(.system(size: 13))
                .foregroundStyle(Color.pmtext.secondary)
            }

            Spacer()

            DatePicker(
              "",
              selection: Binding(
                get: { store.editedSchedule.endAt ?? store.editedSchedule.startAt.addingTimeInterval(7200) },
                set: { store.send(.view(.setEndDate($0))) }
              ),
              in: store.editedSchedule.startAt...,
              displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .tint(Color.pmindigo.n500)
            .environment(\.locale, LocaleManager.appLocale)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .adaptiveGlassCard()
    }

    // MARK: - Minimum Participants Section

    private var minimumParticipantsSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 4) {
          Text(LocalizedStrings.Shared.minimumParticipants)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Text("*")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.red)
        }

        HStack(spacing: 16) {
          Button {
            store.send(.view(.decrementParticipants), animation: .spring(response: 0.3, dampingFraction: 0.7))
          } label: {
            Image(systemName: "minus.circle.fill")
              .font(.system(size: 32))
              .foregroundStyle(store.editedSchedule.minimumParticipants <= 2 ? Color.pmgray.n400 : Color.pmindigo.n500)
              .scaleEffect(isMinusPressed ? 0.85 : 1.0)
          }
          .buttonRepeatBehavior(.enabled)
          .animation(.spring(response: 0.15, dampingFraction: 0.5), value: isMinusPressed)
          .sensoryFeedback(.impact(flexibility: .soft), trigger: store.editedSchedule.minimumParticipants)
          .simultaneousGesture(
            DragGesture(minimumDistance: 0)
              .onChanged { _ in if store.editedSchedule.minimumParticipants > 2 { isMinusPressed = true } }
              .onEnded { _ in isMinusPressed = false }
          )
          .disabled(store.editedSchedule.minimumParticipants <= 2)

          VStack(spacing: 4) {
            Text(LocalizedStrings.LiveSchedule.participantCount(store.editedSchedule.minimumParticipants))
              .font(.system(size: 36, weight: .bold))
              .foregroundStyle(.primary)
              .contentTransition(.numericText())

            Text(LocalizedStrings.Shared.maxMembers(store.maxMembers))
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)

          Button {
            store.send(.view(.incrementParticipants), animation: .spring(response: 0.3, dampingFraction: 0.7))
          } label: {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 32))
              .foregroundStyle(store.editedSchedule.minimumParticipants >= store.maxMembers ? Color.pmgray.n400 : Color.pmindigo.n500)
              .scaleEffect(isPlusPressed ? 0.85 : 1.0)
          }
          .buttonRepeatBehavior(.enabled)
          .animation(.spring(response: 0.15, dampingFraction: 0.5), value: isPlusPressed)
          .sensoryFeedback(.impact(flexibility: .soft), trigger: store.editedSchedule.minimumParticipants)
          .simultaneousGesture(
            DragGesture(minimumDistance: 0)
              .onChanged { _ in if store.editedSchedule.minimumParticipants < store.maxMembers { isPlusPressed = true } }
              .onEnded { _ in isPlusPressed = false }
          )
          .disabled(store.editedSchedule.minimumParticipants >= store.maxMembers)
        }
        .padding(.vertical, 8)

        // 안내 박스
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color.pmindigo.n500)

          Text(LocalizedStrings.Shared.minMembersDescription(store.editedSchedule.minimumParticipants))
            .font(.system(size: 14))
            .foregroundStyle(.primary)

          Spacer()
        }
        .padding(16)
        .background(Color.pmindigo.n50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }

    // MARK: - Realtime Share Section

    private var realtimeShareSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          HStack(spacing: 4) {
            Text(LocalizedStrings.Shared.liveSharing)
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(.primary)

            Text(LocalizedStrings.Shared.optional)
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
          }

          Spacer()

          Toggle("", isOn: Binding(
            get: { store.useRealtimeShare },
            set: { _ in store.send(.view(.toggleUseRealtimeShare), animation: .spring(response: 0.3, dampingFraction: 0.8)) }
          ))
          .labelsHidden()
        }

        if store.useRealtimeShare {
          VStack(spacing: 12) {
            // 시간 선택 버튼들
            HStack(spacing: 8) {
              ForEach([15, 30, 60], id: \.self) { minutes in
                trackingMinuteButton(minutes: minutes)
              }
              // 직접 입력 버튼
              customInputButton
            }

            // 직접 입력 필드
            if isCustomTrackingMinutes {
              HStack(spacing: 12) {
                TextField("", text: $customTrackingMinutesText)
                  .focused($focusedField, equals: .trackingMinutes)
                  .keyboardType(.numberPad)
                  .font(.system(size: 17, weight: .medium))
                  .multilineTextAlignment(.center)
                  .frame(width: 80)
                  .padding(.vertical, 12)
                  .padding(.horizontal, 16)
                  .background(Color(.systemGray6))
                  .clipShape(RoundedRectangle(cornerRadius: 10))
                  .overlay(
                    RoundedRectangle(cornerRadius: 10)
                      .stroke(Color.pmindigo.n500, lineWidth: 2)
                  )
                  .onChange(of: customTrackingMinutesText) { _, newValue in
                    // 숫자만 허용, 최대 3자리
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(3))
                    if filtered != newValue {
                      customTrackingMinutesText = filtered
                    }
                    // 값 업데이트
                    if let minutes = Int(filtered), minutes > 0 {
                      store.send(.view(.setTrackingMinutes(minutes)))
                    }
                  }

                Text(LocalizedStrings.Shared.minutesBeforeStartLabel)
                  .font(.system(size: 15))
                  .foregroundStyle(.secondary)

                Spacer()
              }
              .transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
              ))
            }

            // 안내 박스
            HStack(alignment: .top, spacing: 12) {
              Text("📡")
                .font(.system(size: 18))

              Text(LocalizedStrings.Shared.liveSharingDescription(store.editedSchedule.trackingStartMinutesBefore ?? 30))
                .font(.system(size: 14))
                .foregroundColor(.primary)

              Spacer()
            }
            .padding(16)
            .background(Color.pmindigo.n50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }
        }
      }
      .onAppear {
        // 기존 값이 프리셋이 아니면 직접 입력 모드로 설정
        if let minutes = store.editedSchedule.trackingStartMinutesBefore,
           ![15, 30, 60].contains(minutes) {
          isCustomTrackingMinutes = true
          customTrackingMinutesText = "\(minutes)"
        }
      }
    }

    private var customInputButton: some View {
      Button {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
          isCustomTrackingMinutes = true
          // 현재 값이 프리셋이면 텍스트 필드 비우기, 아니면 현재 값 유지
          if let minutes = store.editedSchedule.trackingStartMinutesBefore,
             ![15, 30, 60].contains(minutes) {
            customTrackingMinutesText = "\(minutes)"
          } else {
            customTrackingMinutesText = ""
          }
        }
        // 포커스 주기
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          focusedField = .trackingMinutes
        }
      } label: {
        Text(LocalizedStrings.Shared.manualStart)
          .font(.system(size: 14, weight: .medium))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(isCustomTrackingMinutes ? Color.pmindigo.n500 : Color(.systemGray6))
          .foregroundStyle(isCustomTrackingMinutes ? .white : .primary)
          .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(ScaleButtonStyle())
      .sensoryFeedback(.selection, trigger: isCustomTrackingMinutes)
    }

    private func trackingMinuteButton(minutes: Int) -> some View {
      let isSelected = store.editedSchedule.trackingStartMinutesBefore == minutes && !isCustomTrackingMinutes

      return Button {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
          isCustomTrackingMinutes = false
          customTrackingMinutesText = ""
        }
        store.send(.view(.setTrackingMinutes(minutes)), animation: .spring(response: 0.2, dampingFraction: 0.7))
      } label: {
        Text(LocalizedStrings.Shared.minutesBefore(minutes))
          .font(.system(size: 14, weight: .medium))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(isSelected ? Color.pmindigo.n500 : Color(.systemGray6))
          .foregroundStyle(isSelected ? .white : .primary)
          .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(ScaleButtonStyle())
      .sensoryFeedback(.selection, trigger: isSelected)
    }
  }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
  }
}

// MARK: - ScheduleClientError Localization

extension Clients.ScheduleClientError {
  var localizedMessage: String {
    switch self {
    case .networkError: return LocalizedStrings.Error.networkError
    case .unauthorized: return LocalizedStrings.Error.userAuthRequired
    case .notFound: return LocalizedStrings.Error.notFoundError
    case .serverError: return LocalizedStrings.Error.serverError
    case .invalidData: return LocalizedStrings.Error.validationError
    case .groupNotFound: return LocalizedStrings.Error.notFoundError
    case .notGroupMember: return LocalizedStrings.Error.permissionError
    case .unknown: return LocalizedStrings.Error.unknownError
    }
  }
}
