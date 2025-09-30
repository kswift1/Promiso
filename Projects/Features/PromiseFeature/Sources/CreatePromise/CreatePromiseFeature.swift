//
//  CreatePromiseFeature.swift
//  PromiseFeature
//
//  Created by 김성원 on 9/30/25.
//

import SwiftUI
import ComposableArchitecture

public enum CreatePromise {
  
  @Reducer
  public struct Feature {
    
    @ObservableState
    public struct State: Equatable {
      var currentStep: CreatePromiseStep = .first
    }
    
    public enum Action: Equatable, Sendable {
      case nextStep
      case previousStep
      case requestCreatingPromise
      case dismiss
      case promiseCreated
    }
    
    public init() {}
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .nextStep:
          state.currentStep.next()
          return .none
        case .previousStep:
          state.currentStep.previous()
          return .none
        case .requestCreatingPromise:
          return .none
        case .dismiss:
          return .none
        case .promiseCreated:
          return .none
        }
      }
    }
  }
}

extension CreatePromise {
  
  struct RootView: View {
    private let store: StoreOf<CreatePromise.Feature>
    
    init(store: StoreOf<CreatePromise.Feature>) {
      self.store = store
    }
    
    var body: some View {
      VStack(spacing: 0) {
          
          // Progress Header
          ProgressHeader(
            currentStep: store.currentStep.rawValue,
            totalSteps: CreatePromiseStep.allCases.count,
            title: "약속 만들기"
          ) {
            store.send(.dismiss)
          }
          
          // Content
          ScrollView {
            VStack(spacing: 24) {
              // HeaderContentView
              CreatePromiseStep.allCases[store.currentStep.rawValue].contentView
              
              
            }
            .padding(16)
          }
          
          Spacer()
          
          // Bottom Buttons
          HStack(spacing: 12) {
            store.currentStep.leftButton(store: store)
            
            store.currentStep.rightButton(store: store)
          }
          .padding(16)
          .background(Color(.systemBackground))
          .overlay(
            Rectangle()
              .fill(Color(.systemGray5))
              .frame(height: 1),
            alignment: .top
          )
        }
        .navigationBarHidden(true)
      }
  }
}

extension CreatePromiseStep {
  @ViewBuilder
  func leftButton(store: StoreOf<CreatePromise.Feature>) -> some View {
    switch self {
    case .first:
      EmptyView()
      
    case .second, .third:
      Button(action: {
        store.send(.previousStep, animation: .default)
      }) {
        Text("이전")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(Color(.systemGray6))
          .cornerRadius(12)
      }
    }
  }
  
  /// 하단 오른쪽 버튼 (다음 or 완료 버튼)
  @ViewBuilder
  func rightButton(store: StoreOf<CreatePromise.Feature>) -> some View {
    switch self {
    case .first, .second:
      Button(action: {
        store.send(.nextStep, animation: .easeInOut(duration: 0.25))
      }) {
        Text("다음")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(Color.blue)
          .cornerRadius(12)
      }
      
    case .third:
      Button(action: {
        store.send(.requestCreatingPromise, animation: .spring(response: 0.3, dampingFraction: 0.9))
      }) {
        Text("약속 제안하기")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(Color.blue)
          .cornerRadius(12)
      }
    }
  }
}
