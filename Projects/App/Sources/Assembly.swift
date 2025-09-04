//
//  Assembly.swift
//  StopLateApp
//
//  Created by 김성원 on 9/4/25.
//

import MainFeatureInterface
import MainFeatureImplement

enum Factories {
  static func main() -> MainEntry { .live() }
}
