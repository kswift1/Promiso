//
//  FAQModel.swift
//  PromisoShared
//
//  Created by Claude on 2026-02-04.
//

import Foundation

// MARK: - FAQ Model

/// 자주 묻는 질문 모델
public struct FAQModel: Equatable, Identifiable, Sendable {
  public let id: String
  public let question: String
  public let answer: String
  public let category: String?
  public let order: Int
  public let isActive: Bool
  public let createdAt: Date

  public init(
    id: String,
    question: String,
    answer: String,
    category: String? = nil,
    order: Int = 0,
    isActive: Bool = true,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.question = question
    self.answer = answer
    self.category = category
    self.order = order
    self.isActive = isActive
    self.createdAt = createdAt
  }
}

// MARK: - Example Data

extension FAQModel {
  public static let examples: [FAQModel] = [
    FAQModel(
      id: "1",
      question: "그룹은 어떻게 만들 수 있나요?",
      answer: "홈 화면에서 '+' 버튼을 눌러 새 그룹을 만들 수 있습니다. 그룹 이름과 이모지를 설정하고 초대 링크를 공유하세요.",
      category: "그룹",
      order: 1
    ),
    FAQModel(
      id: "2",
      question: "약속 알림은 언제 오나요?",
      answer: "약속 시간 30분 전, 10분 전에 푸시 알림이 발송됩니다. 알림 설정에서 시간을 변경할 수 있습니다.",
      category: "알림",
      order: 2
    ),
    FAQModel(
      id: "3",
      question: "캘린더와 동기화하려면 어떻게 해야 하나요?",
      answer: "설정 > 캘린더 설정에서 동기화를 활성화할 수 있습니다. 기본 캘린더 앱 또는 Google 캘린더와 연동됩니다.",
      category: "캘린더",
      order: 3
    ),
  ]
}
