//
//  Assembly.swift
//  StopLateApp
//
//  Created by 김성원 on 9/4/25.
//

import RootTabFeatureInterface
import RootTabFeatureImplement

enum Factories {
  static func main() -> RootTabEntry { .live() }
}
