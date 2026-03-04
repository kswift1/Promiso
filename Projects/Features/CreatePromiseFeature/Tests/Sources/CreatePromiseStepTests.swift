//
//  CreatePromiseStepTests.swift
//  GroupFeature
//
//  CreatePromiseStep 네비게이션 로직 테스트
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/CreatePromise/Models/CreatePromiseStep.swift`
//
//  ## 사용처
//  - **CreatePromiseView**: 스텝 네비게이션 (다음/이전 버튼)
//  - **CreatePromiseFeature**: currentStep 상태 관리
//
//  ## 테스트 목적
//  - 스텝 간 이동 로직 정확성 검증
//  - 경계값(첫 스텝, 마지막 스텝) 처리 검증
//

import Testing
@testable import CreatePromiseFeature

// MARK: - CreatePromiseStep Navigation Tests

@Suite("CreatePromiseStep 네비게이션 테스트")
struct CreatePromiseStepTests {

  // MARK: - next() 테스트

  @Test("first에서 next() 호출 시 second로 이동")
  func next_fromFirst_movesToSecond() {
    var step = CreatePromiseStep.first
    step.next()
    #expect(step == .second)
  }

  @Test("second에서 next() 호출 시 third로 이동")
  func next_fromSecond_movesToThird() {
    var step = CreatePromiseStep.second
    step.next()
    #expect(step == .third)
  }

  @Test("third(마지막)에서 next() 호출 시 third 유지 (경계값)")
  func next_fromThird_staysAtThird() {
    var step = CreatePromiseStep.third
    step.next()
    #expect(step == .third)
  }

  // MARK: - previous() 테스트

  @Test("third에서 previous() 호출 시 second로 이동")
  func previous_fromThird_movesToSecond() {
    var step = CreatePromiseStep.third
    step.previous()
    #expect(step == .second)
  }

  @Test("second에서 previous() 호출 시 first로 이동")
  func previous_fromSecond_movesToFirst() {
    var step = CreatePromiseStep.second
    step.previous()
    #expect(step == .first)
  }

  @Test("first(첫 스텝)에서 previous() 호출 시 first 유지 (경계값)")
  func previous_fromFirst_staysAtFirst() {
    var step = CreatePromiseStep.first
    step.previous()
    #expect(step == .first)
  }

  // MARK: - + 연산자 테스트

  @Test("first + 1 = second")
  func plus_operator_addsStep() {
    let result = CreatePromiseStep.first + 1
    #expect(result == .second)
  }

  @Test("first + 2 = third")
  func plus_operator_addsTwoSteps() {
    let result = CreatePromiseStep.first + 2
    #expect(result == .third)
  }

  @Test("first + 10 = third (최대 경계값 처리)")
  func plus_operator_clampsToMax() {
    let result = CreatePromiseStep.first + 10
    #expect(result == .third)
  }

  // MARK: - - 연산자 테스트

  @Test("third - 1 = second")
  func minus_operator_subtractsStep() {
    let result = CreatePromiseStep.third - 1
    #expect(result == .second)
  }

  @Test("third - 2 = first")
  func minus_operator_subtractsTwoSteps() {
    let result = CreatePromiseStep.third - 2
    #expect(result == .first)
  }

  @Test("third - 10 = first (최소 경계값 처리)")
  func minus_operator_clampsToMin() {
    let result = CreatePromiseStep.third - 10
    #expect(result == .first)
  }

  // MARK: - += 연산자 테스트

  @Test("+= 연산자로 스텝 증가")
  func plusEquals_operator_incrementsStep() {
    var step = CreatePromiseStep.first
    step += 1
    #expect(step == .second)
  }

  // MARK: - -= 연산자 테스트

  @Test("-= 연산자로 스텝 감소")
  func minusEquals_operator_decrementsStep() {
    var step = CreatePromiseStep.third
    step -= 1
    #expect(step == .second)
  }

  // MARK: - rawValue 테스트

  @Test("스텝별 rawValue가 0, 1, 2")
  func rawValues_areSequential() {
    #expect(CreatePromiseStep.first.rawValue == 0)
    #expect(CreatePromiseStep.second.rawValue == 1)
    #expect(CreatePromiseStep.third.rawValue == 2)
  }

  // MARK: - allCases 테스트

  @Test("allCases에 3개 스텝 포함")
  func allCases_containsThreeSteps() {
    #expect(CreatePromiseStep.allCases.count == 3)
    #expect(CreatePromiseStep.allCases == [.first, .second, .third])
  }
}
