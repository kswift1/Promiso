import SwiftUI

struct SectionPlaceHolder<Content: View>: View {
    private let placeHolderTitle: String
    private let isRequired: Bool
    private let content: () -> Content
    
    init(placeHolderTitle: String, isRequired: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.placeHolderTitle = placeHolderTitle
        self.isRequired = isRequired
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Text(placeHolderTitle)
                    .font(.system(size: 14))
                
                if isRequired {
                    Text("*")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
            }
            
            content()
        }
    }
}

// MARK: - Previews

#Preview("필수 필드") {
    SectionPlaceHolder(
        placeHolderTitle: "제목",
        isRequired: true
    ) {
        TextField("약속 제목을 입력하세요", text: .constant(""))
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}

#Preview("선택 필드") {
    SectionPlaceHolder(
        placeHolderTitle: "장소",
        isRequired: false
    ) {
        TextField("장소를 입력하세요", text: .constant(""))
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}

#Preview("텍스트 영역") {
    SectionPlaceHolder(
        placeHolderTitle: "상세 설명",
        isRequired: false
    ) {
        TextEditor(text: .constant(""))
            .frame(height: 120)
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}

#Preview("DatePicker") {
    SectionPlaceHolder(
        placeHolderTitle: "시작 시간",
        isRequired: true
    ) {
        DatePicker(
            "",
            selection: .constant(Date()),
            displayedComponents: [.date, .hourAndMinute]
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}

#Preview("커스텀 컨텐츠") {
    SectionPlaceHolder(
        placeHolderTitle: "참가 인원",
        isRequired: true
    ) {
        HStack {
            Button(action: {}) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 32))
            }
            
            Spacer()
            
            VStack {
                Text("3명")
                    .font(.system(size: 28, weight: .bold))
                Text("최대 10명")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}

#Preview("여러 섹션") {
    VStack(spacing: 24) {
        SectionPlaceHolder(
            placeHolderTitle: "제목",
            isRequired: true
        ) {
            TextField("약속 제목", text: .constant("영화 관람"))
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        
        SectionPlaceHolder(
            placeHolderTitle: "장소",
            isRequired: false
        ) {
            TextField("장소 입력", text: .constant(""))
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        
        SectionPlaceHolder(
            placeHolderTitle: "메모",
            isRequired: false
        ) {
            TextEditor(text: .constant(""))
                .frame(height: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding()
}

#Preview("다크모드") {
    VStack(spacing: 24) {
        SectionPlaceHolder(
            placeHolderTitle: "이름",
            isRequired: true
        ) {
            TextField("이름을 입력하세요", text: .constant(""))
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        
        SectionPlaceHolder(
            placeHolderTitle: "이메일",
            isRequired: false
        ) {
            TextField("이메일을 입력하세요", text: .constant(""))
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("긴 제목") {
    SectionPlaceHolder(
        placeHolderTitle: "이것은 매우 긴 섹션 플레이스홀더 제목입니다",
        isRequired: true
    ) {
        TextField("내용 입력", text: .constant(""))
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}

#Preview("Toggle 컨트롤") {
    SectionPlaceHolder(
        placeHolderTitle: "종료 시간 사용",
        isRequired: false
    ) {
        Toggle("", isOn: .constant(true))
            .labelsHidden()
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}

#Preview("버튼 그룹") {
    SectionPlaceHolder(
        placeHolderTitle: "미리 알림",
        isRequired: false
    ) {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("5분 전") {}
                    .buttonStyle(.bordered)
                Button("15분 전") {}
                    .buttonStyle(.borderedProminent)
                Button("30분 전") {}
                    .buttonStyle(.bordered)
            }
            HStack(spacing: 8) {
                Button("1시간 전") {}
                    .buttonStyle(.bordered)
                Button("3시간 전") {}
                    .buttonStyle(.bordered)
                Button("1일 전") {}
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}

#Preview("전체 폼 예시") {
    ScrollView {
        VStack(spacing: 24) {
            Text("약속 만들기")
                .font(.title)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            SectionPlaceHolder(
                placeHolderTitle: "제목",
                isRequired: true
            ) {
                TextField("약속 제목을 입력하세요", text: .constant(""))
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            SectionPlaceHolder(
                placeHolderTitle: "그룹",
                isRequired: true
            ) {
                Menu {
                    Button("대학 친구들") {}
                    Button("개발팀") {}
                    Button("가족") {}
                } label: {
                    HStack {
                        Text("그룹 선택")
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            SectionPlaceHolder(
                placeHolderTitle: "시작 시간",
                isRequired: true
            ) {
                DatePicker("", selection: .constant(Date()))
                    .labelsHidden()
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            SectionPlaceHolder(
                placeHolderTitle: "장소",
                isRequired: false
            ) {
                TextField("장소를 검색하세요", text: .constant(""))
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}
