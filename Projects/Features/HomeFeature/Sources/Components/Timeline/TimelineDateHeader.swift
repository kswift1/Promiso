import SwiftUI
import PromisoShared

struct TimelineDateHeader: View {
  let date: Date

  var body: some View {
    HStack(spacing: 12) {
      Text(dateText)
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(.primary)

      Rectangle()
        .fill(Color(UIColor.systemGray4))
        .frame(height: 1)
    }
    .padding(.top, 8)
    .padding(.bottom, 8)
  }

  private var dateText: String {
    let calendar = Calendar.current
    let now = Date()

    if calendar.isDateInToday(date) {
      return "오늘"
    } else if calendar.isDateInTomorrow(date) {
      return "내일"
    } else if calendar.isDate(date, equalTo: now.addingTimeInterval(86400 * 2), toGranularity: .day) {
      return "모레"
    } else {
      return KoreanDateFormatters.sectionHeader.string(from: date)
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 0) {
    TimelineDateHeader(date: Date())
    TimelineDateHeader(date: Date().addingTimeInterval(86400))
    TimelineDateHeader(date: Date().addingTimeInterval(86400 * 2))
    TimelineDateHeader(date: Date().addingTimeInterval(86400 * 7))
  }
  .padding()
  .auroraBackground()
}
