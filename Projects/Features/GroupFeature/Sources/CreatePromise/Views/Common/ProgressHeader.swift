import SwiftUI

// MARK: - Progress Header Component
struct ProgressHeader: View {
    let currentStep: Int
    let totalSteps: Int
    let title: String
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더 영역
            HStack {
                // 닫기 버튼
                Button(action: onDismiss) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 36, height: 36)

                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }

                Spacer()

                // 제목
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // 프로그레스 바
            HStack(spacing: 8) {
                ForEach(0...totalSteps-1, id: \.self) { step in
                    ProgressSegment(isActive: step <= currentStep)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .overlay(
            // 하단 구분선
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Progress Segment
struct ProgressSegment: View {
    @State private var hasAppeared: Bool = false
    let isActive: Bool

    private let firstDelay: TimeInterval = 0.2
    private let animationDuration: TimeInterval = 0.5

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 배경
                Rectangle()
                    .fill(Color(.systemGray5))

                // 활성화된 프로그레스 (Gradient)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: (isActive && hasAppeared) ? geometry.size.width : 0)
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.easeInOut(duration: animationDuration).delay(firstDelay)) {
                hasAppeared = true
            }
        }
        .onChange(of: isActive) { oldValue, newValue in
            guard hasAppeared else { return }
            if newValue {
                // 다음 단계로: 채워지는 애니메이션
                withAnimation(.easeOut(duration: animationDuration)) {
                    // isActive 변경 시 자동으로 애니메이션
                }
            } else {
                // 이전 단계로: 비워지는 애니메이션
                withAnimation(.easeIn(duration: animationDuration)) {
                    // isActive 변경 시 자동으로 애니메이션
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Step 0 (1/3)") {
    ProgressHeader(
        currentStep: 0,
        totalSteps: 3,
        title: "약속 만들기"
    ) {
        print("닫기 버튼 탭")
    }
}

#Preview("Step 1 (2/3)") {
    ProgressHeader(
        currentStep: 1,
        totalSteps: 3,
        title: "약속 만들기"
    ) {
        print("닫기 버튼 탭")
    }
}

#Preview("Step 2 (3/3)") {
    ProgressHeader(
        currentStep: 2,
        totalSteps: 3,
        title: "약속 만들기"
    ) {
        print("닫기 버튼 탭")
    }
}

#Preview("4단계 진행 중") {
    VStack(spacing: 20) {
        ProgressHeader(
            currentStep: 0,
            totalSteps: 4,
            title: "설문조사"
        ) { }
        
        ProgressHeader(
            currentStep: 1,
            totalSteps: 4,
            title: "설문조사"
        ) { }
        
        ProgressHeader(
            currentStep: 2,
            totalSteps: 4,
            title: "설문조사"
        ) { }
        
        ProgressHeader(
            currentStep: 3,
            totalSteps: 4,
            title: "설문조사"
        ) { }
    }
}

#Preview("긴 제목") {
    ProgressHeader(
        currentStep: 1,
        totalSteps: 3,
        title: "새로운 프로젝트 생성하기"
    ) {
        print("닫기")
    }
}

#Preview("다크모드") {
    VStack(spacing: 20) {
        ProgressHeader(
            currentStep: 0,
            totalSteps: 3,
            title: "약속 만들기"
        ) { }
        
        ProgressHeader(
            currentStep: 1,
            totalSteps: 3,
            title: "약속 만들기"
        ) { }
        
        ProgressHeader(
            currentStep: 2,
            totalSteps: 3,
            title: "약속 만들기"
        ) { }
    }
    .preferredColorScheme(.dark)
}

#Preview("애니메이션 테스트") {
    struct AnimationTestView: View {
        @State private var currentStep = 0
        
        var body: some View {
            VStack(spacing: 0) {
                ProgressHeader(
                    currentStep: currentStep,
                    totalSteps: 3,
                    title: "약속 만들기"
                ) {
                    currentStep = 0
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Text("현재 단계: \(currentStep + 1)/3")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Button("이전") {
                            withAnimation {
                                if currentStep > 0 {
                                    currentStep -= 1
                                }
                            }
                        }
                        .disabled(currentStep == 0)
                        
                        Button("다음") {
                            withAnimation {
                                if currentStep < 2 {
                                    currentStep += 1
                                }
                            }
                        }
                        .disabled(currentStep == 2)
                        
                        Button("초기화") {
                            withAnimation {
                                currentStep = 0
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                
                Spacer()
            }
        }
    }
    
    return AnimationTestView()
}

#Preview("전체 화면 컨텍스트") {
    VStack(spacing: 0) {
        ProgressHeader(
            currentStep: 1,
            totalSteps: 3,
            title: "약속 만들기"
        ) {
            print("닫기")
        }
        
        ScrollView {
            VStack(spacing: 24) {
                Text("Step 2 내용")
                    .font(.title)
                    .padding()
                
                ForEach(0..<10) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .frame(height: 100)
                        .overlay(
                            Text("항목 \(index + 1)")
                        )
                }
            }
            .padding()
        }
        
        // 하단 버튼
        HStack(spacing: 12) {
            Button("이전") { }
                .frame(maxWidth: .infinity)
            Button("다음") { }
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1),
            alignment: .top
        )
    }
}
