import SwiftUI
import ComposableArchitecture

struct EndDateTimeSection: View {
    let store: StoreOf<CreatePromise.Feature>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // PlaceHolder with Toggle
            HStack {
                HStack(spacing: 3) {
                    Text("종료 시간")
                        .font(.system(size: 14))
                    
                    Text("(선택)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { store.useEndTime },
                    set: { _ in store.send(.toggleUseEndTime) }
                ))
                .labelsHidden()
            }
            
            // Duration Picker
            if store.useEndTime {
                DurationBasedEndTimePicker(
                    startDate: store.promiseProposal.startedAt,
                    endDate: Binding(
                        get: {
                            store.promiseProposal.endedAt ?? store.promiseProposal.startedAt.addingTimeInterval(7200)
                        },
                        set: { store.send(.setEndDate($0)) }
                    )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.useEndTime)
    }
}

// MARK: - Duration Based End Time Picker
struct DurationBasedEndTimePicker: View {
    let startDate: Date
    @Binding var endDate: Date
    @State private var showCustomPicker = false
    
    private let quickDurations: [(title: String, hours: Double)] = [
        ("30분", 0.5),
        ("1시간", 1),
        ("1시간 30분", 1.5),
        ("2시간", 2),
        ("3시간", 3),
        ("4시간", 4)
    ]
    
    private var currentDuration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    private var durationText: String {
        let hours = Int(currentDuration / 3600)
        let minutes = Int((currentDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 && minutes > 0 {
            return "\(hours)시간 \(minutes)분"
        } else if hours > 0 {
            return "\(hours)시간"
        } else {
            return "\(minutes)분"
        }
    }
    
    private var endTimeText: String {
        endDate.formatted(date: .omitted, time: .shortened)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 현재 설정 표시
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("소요 시간")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(durationText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("종료 시간")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(endTimeText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 빠른 선택 버튼
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(quickDurations, id: \.title) { duration in
                    let isSelected = abs(currentDuration - (duration.hours * 3600)) < 60
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            endDate = startDate.addingTimeInterval(duration.hours * 3600)
                        }
                    }) {
                        Text(duration.title)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isSelected ? Color.blue : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // 커스텀 시간 설정 버튼
            Button(action: { showCustomPicker = true }) {
                HStack {
                    Image(systemName: "clock.badge.plus")
                        .font(.system(size: 14))
                    Text("직접 시간 설정")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showCustomPicker) {
            CustomEndTimePickerSheet(
                startDate: startDate,
                endDate: $endDate,
                showPicker: $showCustomPicker
            )
        }
    }
}

// MARK: - Custom End Time Picker Sheet
struct CustomEndTimePickerSheet: View {
    let startDate: Date
    @Binding var endDate: Date
    @Binding var showPicker: Bool
    @State private var tempDate: Date
    
    init(startDate: Date, endDate: Binding<Date>, showPicker: Binding<Bool>) {
        self.startDate = startDate
        self._endDate = endDate
        self._showPicker = showPicker
        self._tempDate = State(initialValue: endDate.wrappedValue)
    }
    
    private var duration: TimeInterval {
        tempDate.timeIntervalSince(startDate)
    }
    
    private var durationText: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 && minutes > 0 {
            return "\(hours)시간 \(minutes)분 소요"
        } else if hours > 0 {
            return "\(hours)시간 소요"
        } else {
            return "\(minutes)분 소요"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 시작 시간 표시
                VStack(spacing: 8) {
                    Text("시작")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(startDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // 화살표 & 소요 시간
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    Text(durationText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 16)
                
                // 종료 시간 표시
                VStack(spacing: 8) {
                    Text("종료")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(tempDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 20, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue.opacity(0.08))
                
                Divider()
                    .padding(.top, 8)
                
                // DatePicker
                DatePicker(
                    "",
                    selection: $tempDate,
                    in: startDate...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("종료 시간 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        showPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        endDate = tempDate
                        showPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Toggle OFF") {
    EndDateTimeSection(
        store: Store(
            initialState: CreatePromise.Feature.State(
                promiseProposal: PromiseProposal(
                    title: "영화 관람",
                    emoji: "🍿",
                    groupID: "1",
                    startedAt: Date().addingTimeInterval(7200),
                    endedAt: nil,
                    minimumParticipants: 2
                )
            )
        ) {
            CreatePromise.Feature()
        }
    )
    .padding()
}

#Preview("Toggle ON - 2시간") {
    EndDateTimeSection(
        store: Store(
            initialState: CreatePromise.Feature.State(
                promiseProposal: PromiseProposal(
                    title: "영화 관람",
                    emoji: "🍿",
                    groupID: "1",
                    startedAt: Date().addingTimeInterval(7200),
                    endedAt: Date().addingTimeInterval(7200 + 7200),
                    minimumParticipants: 2
                )
            )
        ) {
            CreatePromise.Feature()
        }
    )
    .padding()
}

#Preview("Toggle ON - 1시간 30분") {
    EndDateTimeSection(
        store: Store(
            initialState: CreatePromise.Feature.State(
                promiseProposal: PromiseProposal(
                    title: "카페 미팅",
                    emoji: "☕",
                    groupID: "1",
                    startedAt: Date().addingTimeInterval(7200),
                    endedAt: Date().addingTimeInterval(7200 + 5400),
                    minimumParticipants: 2
                )
            )
        ) {
            CreatePromise.Feature()
        }
    )
    .padding()
}

#Preview("다크모드") {
    VStack(spacing: 24) {
        EndDateTimeSection(
            store: Store(
                initialState: CreatePromise.Feature.State(
                    promiseProposal: PromiseProposal(
                        title: "저녁 식사",
                        emoji: "🍽️",
                        groupID: "1",
                        startedAt: Date().addingTimeInterval(7200),
                        endedAt: Date().addingTimeInterval(7200 + 7200),
                        minimumParticipants: 2
                    )
                )
            ) {
                CreatePromise.Feature()
            }
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("전체 폼") {
    ScrollView {
        VStack(spacing: 24) {
            Text("Step 2 - 날짜/시간")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            SectionPlaceHolder(
                placeHolderTitle: "시작 시간",
                isRequired: true
            ) {
                Text("오후 7:00")
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            EndDateTimeSection(
                store: Store(
                    initialState: CreatePromise.Feature.State(
                        promiseProposal: PromiseProposal(
                            title: "카페 미팅",
                            emoji: "☕",
                            groupID: "1",
                            startedAt: Date().addingTimeInterval(7200),
                            endedAt: Date().addingTimeInterval(7200 + 5400),
                            minimumParticipants: 2
                        )
                    )
                ) {
                    CreatePromise.Feature()
                }
            )
        }
        .padding()
    }
}

#Preview("커스텀 Sheet") {
    struct PreviewWrapper: View {
        @State private var endDate = Date().addingTimeInterval(10800)
        @State private var showPicker = true
        
        var body: some View {
            Text("Sheet")
                .sheet(isPresented: $showPicker) {
                    CustomEndTimePickerSheet(
                        startDate: Date().addingTimeInterval(7200),
                        endDate: $endDate,
                        showPicker: $showPicker
                    )
                }
        }
    }
    
    return PreviewWrapper()
}
