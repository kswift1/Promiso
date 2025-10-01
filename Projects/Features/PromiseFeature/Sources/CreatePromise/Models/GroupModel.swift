//
//  GroupModel.swift
//  PromiseFeature
//
//  Created by 김성원 on 10/1/25.
//

import Foundation

public struct GroupModel: Equatable, Identifiable, Sendable {
  public let id: String
  let emoji: String
  let title: String
  let memberCount: Int
}
