import SwiftUI

struct HeaderContentView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension CreatePromiseStep {
    var headerView: HeaderContentView {
        HeaderContentView(title: title, subtitle: subtitle)
    }
    
    private var title: String {
        switch self {
        case .first: "어떤 약속인가요?"
        case .second: "언제, 어디서 만날까요?"
        case .third: "추가 설정"
        }
    }
    
    private var subtitle: String {
        switch self {
        case .first: "기본 정보를 입력해주세요"
        case .second: "날짜, 시간, 장소를 정해주세요"
        case .third: "알림과 상세 설명을 설정하세요"
        }
    }
}

// MARK: - Previews

#Preview("Step 1 헤더") {
    CreatePromiseStep.first.headerView
        .padding()
}

#Preview("Step 2 헤더") {
    CreatePromiseStep.second.headerView
        .padding()
}

#Preview("Step 3 헤더") {
    CreatePromiseStep.third.headerView
        .padding()
}

#Preview("커스텀 헤더") {
    HeaderContentView(
        title: "커스텀 제목",
        subtitle: "커스텀 부제목입니다"
    )
    .padding()
}

#Preview("긴 텍스트") {
    HeaderContentView(
        title: "이것은 매우 긴 제목입니다. 여러 줄로 표시될 수 있습니다.",
        subtitle: "이것은 매우 긴 부제목입니다. 사용자에게 더 많은 정보를 제공하기 위해 여러 줄로 작성되었습니다."
    )
    .padding()
}

#Preview("다크모드") {
    VStack(spacing: 24) {
        CreatePromiseStep.first.headerView
        CreatePromiseStep.second.headerView
        CreatePromiseStep.third.headerView
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("모든 Step 비교") {
    VStack(spacing: 32) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step 1")
                .font(.caption)
                .foregroundColor(.secondary)
            CreatePromiseStep.first.headerView
            Divider()
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Step 2")
                .font(.caption)
                .foregroundColor(.secondary)
            CreatePromiseStep.second.headerView
            Divider()
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Step 3")
                .font(.caption)
                .foregroundColor(.secondary)
            CreatePromiseStep.third.headerView
            Divider()
        }
    }
    .padding()
}

#Preview("컨텍스트 내에서") {
    VStack(alignment: .leading, spacing: 24) {
        CreatePromiseStep.first.headerView
        
        // 실제 사용 예시
        VStack(alignment: .leading, spacing: 12) {
            Text("제목")
                .font(.system(size: 16, weight: .semibold))
            
            TextField("약속 제목을 입력하세요", text: .constant(""))
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("그룹 선택")
                .font(.system(size: 16, weight: .semibold))
            
            Text("그룹을 선택해주세요")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding()
}

#Preview("다양한 배경색") {
    ScrollView {
        VStack(spacing: 0) {
            // 흰색 배경
            CreatePromiseStep.first.headerView
                .padding()
                .background(Color.white)
            
            // 회색 배경
            CreatePromiseStep.second.headerView
                .padding()
                .background(Color(.systemGray6))
            
            // 파란색 배경
            CreatePromiseStep.third.headerView
                .padding()
                .background(Color.blue.opacity(0.1))
        }
    }
}

#Preview("애니메이션 테스트") {
    struct AnimationTestView: View {
        @State private var currentStep = 0
        
        var body: some View {
            VStack(spacing: 24) {
                [CreatePromiseStep.first, .second, .third][currentStep].headerView
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                
                HStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        Button(action: {
                            withAnimation {
                                currentStep = index
                            }
                        }) {
                            Text("Step \(index + 1)")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(currentStep == index ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(currentStep == index ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    return AnimationTestView()
}
