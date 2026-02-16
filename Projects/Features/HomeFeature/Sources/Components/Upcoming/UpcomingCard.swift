import SwiftUI
import Clients
import PromisoShared
import ResourceKit

// MARK: - Upcoming Date Card

/// 같은 날짜의 일정들을 하나의 카드로 묶는 컴포넌트
struct UpcomingDateCard: View {
  let date: Date
  let items: [HomeModels.ScheduleItem]
  let onItemTap: (HomeModels.ScheduleItem) -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // 날짜 배지
      dateBadge

      // 일정 목록
      VStack(spacing: 0) {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
          switch item {
          case .promise(let promise):
            UpcomingPromiseRow(
              promise: promise,
              onTap: { onItemTap(item) }
            )

          case .personalEvent(let event):
            UpcomingPersonalEventRow(
              event: event,
              onTap: { onItemTap(item) }
            )
          }

          // 마지막 아이템이 아니면 Divider
          if index < items.count - 1 {
            Divider()
              .padding(.vertical, 8)
          }
        }
      }
    }
    .padding(12)
    .background(Color.pmindigo.n500.opacity(0.03))
    .adaptiveGlassCard(cornerRadius: 14)
  }

  // MARK: - Date Badge

  private var dateBadge: some View {
    VStack(spacing: 2) {
      Text(monthString)
        .font(.pmCaption2Medium)
        .foregroundStyle(Color.pmindigo.n500)

      Text(dayString)
        .font(.pmTitle3)
        .foregroundStyle(.primary)

      Text(weekdayString)
        .font(.pmCaption2)
        .foregroundStyle(weekdayColor)
    }
    .frame(width: 44)
    .padding(.vertical, 6)
    .background(Color.pmindigo.n500.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  // MARK: - Computed Properties

  private var monthString: String {
    LocalizedDateFormatters.month.string(from: date)
  }

  private var dayString: String {
    LocalizedDateFormatters.day.string(from: date)
  }

  private var weekdayString: String {
    LocalizedDateFormatters.weekday.string(from: date)
  }

  private var weekdayColor: Color {
    let weekday = Calendar.current.component(.weekday, from: date)
    switch weekday {
    case 1: return .red      // 일요일
    case 7: return .blue     // 토요일
    default: return .secondary
    }
  }
}

// MARK: - Upcoming Promise Row

/// 카드 내부의 개별 약속 행
private struct UpcomingPromiseRow: View {
  let promise: PromiseModel
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 8) {
        // 약속 정보
        VStack(alignment: .leading, spacing: 4) {
          // 이모지 + 제목
          HStack(spacing: 6) {
            Text(promise.displayEmoji)
              .font(.pmBody)

            Text(promise.title)
              .font(.pmSubheadlineMedium)
              .foregroundStyle(.primary)
              .lineLimit(1)
          }

          // 시간 + 장소
          HStack(spacing: 12) {
            // 시간
            HStack(spacing: 3) {
              ResourceKitAsset.clockIcon.swiftUIImage
                .resizable()
                .renderingMode(.template)
                .frame(width: 12, height: 12)

              Text(timeString)
                .font(.pmCaption)
            }

            // 장소
            if let location = promise.location {
              HStack(spacing: 3) {
                ResourceKitAsset.locationIcon.swiftUIImage
                  .resizable()
                  .renderingMode(.template)
                  .frame(width: 12, height: 12)

                Text(location.name)
                  .font(.pmCaption)
                  .lineLimit(1)
              }
            }
          }
          .foregroundStyle(.secondary)

          // 그룹 · 참여자
          groupParticipantsView
        }

        Spacer(minLength: 0)

        // 우측 화살표
        Image(systemName: "chevron.right")
          .font(.pmCaption)
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Group & Participants View

  private var groupParticipantsView: some View {
    HStack(spacing: 4) {
      // 그룹 아이콘
      GroupThumbnailView(
        imageUrl: promise.group?.imageUrl,
        name: promise.group?.name ?? "",
        size: 14
      )

      // 그룹명 · 참여자
      if let groupName = promise.group?.name {
        Text(LocalizedStrings.Home.groupParticipants(groupName, promise.votes.accepted.count))
          .font(.pmCaption)
      } else {
        Text(LocalizedStrings.Home.participantsConfirmed(promise.votes.accepted.count))
          .font(.pmCaption)
      }
    }
    .foregroundStyle(.secondary)
  }

  // MARK: - Computed Properties

  private var timeString: String {
    promise.startAt.formattedTime
  }
}

// MARK: - Upcoming Personal Event Row

/// 카드 내부의 개별 개인 일정 행
private struct UpcomingPersonalEventRow: View {
  let event: PersonalEventModel
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 8) {
        // 일정 정보
        VStack(alignment: .leading, spacing: 4) {
          // 이모지 + 제목
          HStack(spacing: 6) {
            Text(event.displayEmoji)
              .font(.pmBody)

            Text(event.title)
              .font(.pmSubheadlineMedium)
              .foregroundStyle(.primary)
              .lineLimit(1)
          }

          // 시간 + 장소
          HStack(spacing: 12) {
            // 시간
            HStack(spacing: 3) {
              ResourceKitAsset.clockIcon.swiftUIImage
                .resizable()
                .renderingMode(.template)
                .frame(width: 12, height: 12)

              Text(timeString)
                .font(.pmCaption)
            }

            // 장소
            if let location = event.location {
              HStack(spacing: 3) {
                ResourceKitAsset.locationIcon.swiftUIImage
                  .resizable()
                  .renderingMode(.template)
                  .frame(width: 12, height: 12)

                Text(location.name)
                  .font(.pmCaption)
                  .lineLimit(1)
              }
            }
          }
          .foregroundStyle(.secondary)

          // 개인 일정 라벨
          HStack(spacing: 4) {
            Image(systemName: "person.fill")
              .font(.system(size: 10))

            Text(LocalizedStrings.Common.personalEvent)
              .font(.pmCaption)
          }
          .foregroundStyle(.secondary)
        }

        Spacer(minLength: 0)

        // 우측 화살표
        Image(systemName: "chevron.right")
          .font(.pmCaption)
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Computed Properties

  private var timeString: String {
    event.startAt.formattedTime
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 10) {
    // 같은 날짜에 약속 + 개인 일정 혼합
    UpcomingDateCard(
      date: Date().addingTimeInterval(86400),
      items: [
        .promise(PromiseModel.mock(id: "1", title: "팀 미팅", startAt: Date().addingTimeInterval(86400))),
        .personalEvent(PersonalEventModel.mock(
          id: "pe-1",
          title: "치과 예약",
          emoji: "🦷",
          startAt: Date().addingTimeInterval(86400 + 3600),
          location: LocationInfoModel(name: "서울치과")
        )),
        .promise(PromiseModel.mock(id: "3", title: "저녁 약속", startAt: Date().addingTimeInterval(86400 + 7200)))
      ],
      onItemTap: { _ in }
    )

    // 하루에 개인 일정만
    UpcomingDateCard(
      date: Date().addingTimeInterval(172800),
      items: [
        .personalEvent(PersonalEventModel.mock(
          id: "pe-2",
          title: "프로젝트 발표",
          emoji: "💼",
          startAt: Date().addingTimeInterval(172800)
        ))
      ],
      onItemTap: { _ in }
    )
  }
  .padding()
  .auroraBackground()
}
