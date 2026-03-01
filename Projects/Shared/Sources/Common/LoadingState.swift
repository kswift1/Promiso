//
//  LoadingState.swift
//  Shared
//
//  비동기 데이터 로딩 상태 관리
//

import Foundation

/// 비동기 데이터 로딩 상태
public enum LoadingState<T: Equatable>: Equatable {
  /// 초기 상태 (아직 로딩 시작 안 함)
  case idle

  /// 로딩 중
  case loading

  /// 로드 완료
  case loaded(T)

  /// 에러 발생
  case failed(Error)

  // MARK: - Computed Properties

  /// 로딩 중인지 여부
  public var isLoading: Bool {
    if case .loading = self { return true }
    return false
  }

  /// 로드 완료 여부
  public var isLoaded: Bool {
    if case .loaded = self { return true }
    return false
  }

  /// 실패 여부
  public var isFailed: Bool {
    if case .failed = self { return true }
    return false
  }

  /// 데이터 추출 (로드 완료 상태에서만)
  public var value: T? {
    if case .loaded(let value) = self {
      return value
    }
    return nil
  }

  /// 에러 추출 (실패 상태에서만)
  public var error: Error? {
    if case .failed(let error) = self {
      return error
    }
    return nil
  }

  // MARK: - Equatable

  public static func == (lhs: LoadingState<T>, rhs: LoadingState<T>) -> Bool {
    switch (lhs, rhs) {
    case (.idle, .idle):
      return true
    case (.loading, .loading):
      return true
    case (.loaded(let lhsValue), .loaded(let rhsValue)):
      return lhsValue == rhsValue
    case (.failed(let lhsError), .failed(let rhsError)):
      return lhsError.localizedDescription == rhsError.localizedDescription
    default:
      return false
    }
  }
}

// MARK: - Error Extension

public extension LoadingState {
  /// 에러 메시지 가져오기
  var errorMessage: String? {
    if case .failed(let error) = self {
      return error.localizedDescription
    }
    return nil
  }
}

// MARK: - Map

public extension LoadingState {
  /// 로드된 값 변환
  func map<U: Equatable>(_ transform: (T) -> U) -> LoadingState<U> {
    switch self {
    case .idle:
      return .idle
    case .loading:
      return .loading
    case .loaded(let value):
      return .loaded(transform(value))
    case .failed(let error):
      return .failed(error)
    }
  }
}
