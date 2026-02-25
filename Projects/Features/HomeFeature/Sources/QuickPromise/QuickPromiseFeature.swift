import Clients
import ComposableArchitecture
import PhotosUI
import _PhotosUI_SwiftUI
import PromisoShared

// MARK: - Feature Namespace

public enum QuickPromise {}

// MARK: - Reducer

extension QuickPromise {

  @Reducer
  public struct Feature {
    @Dependency(\.promiseExtractionClient) var extractionClient

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 입력 텍스트
      var inputText: String = ""

      /// 추출된 약속 정보
      var extractedInfo: PromiseExtractedInfo?

      /// 추출 중 로딩 상태
      var isExtracting: Bool = false

      /// 에러 메시지
      var extractionError: String?

      /// 이미지에서 추출 중 로딩 상태
      var isExtractingFromImage: Bool = false

      public init() {}
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum View: Sendable {
        /// 텍스트 입력 변경
        case textChanged(String)
        /// 텍스트 분석 버튼 탭
        case analyzeTextTapped
        /// 이미지 선택됨
        case photoSelected(PhotosPickerItem?)
        /// 약속 만들기 버튼 탭
        case createPromiseTapped
        /// 초기화
        case clearTapped
        /// 에러 닫기
        case errorDismissed
        /// Share Extension에서 공유된 콘텐츠 로드 + 자동 분석
        case loadSharedContent
      }

      @CasePathable
      public enum Internal: Sendable {
        /// 텍스트 추출 결과
        case textExtractionResult(Result<PromiseExtractedInfo, Error>)
        /// 이미지 추출 결과
        case imageExtractionResult(Result<PromiseExtractedInfo, Error>)
        /// 이미지 로드 완료
        case imageDataLoaded(Data?)
        /// Share Extension 공유 콘텐츠 로드 결과
        case sharedContentLoaded(type: String?, text: String?, imageData: Data?)
      }

      @CasePathable
      public enum Delegate: Sendable {
        /// 약속 생성 요청 (추출 정보를 CreatePromise로 전달)
        case createPromiseRequested(PromiseExtractedInfo)
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .textChanged(let text):
            state.inputText = text
            // 텍스트가 비면 추출 결과 초기화
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              state.extractedInfo = nil
              state.extractionError = nil
            }
            return .none

          case .analyzeTextTapped:
            let text = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return .none }

            state.isExtracting = true
            state.extractionError = nil
            return .run { [extractionClient] send in
              do {
                let info = try await extractionClient.extractFromText(text)
                await send(.internal(.textExtractionResult(.success(info))))
              } catch {
                await send(.internal(.textExtractionResult(.failure(error))))
              }
            }

          case .photoSelected(let item):
            guard let item else { return .none }
            state.isExtractingFromImage = true
            state.extractionError = nil
            return .run { send in
              let data = try? await item.loadTransferable(type: Data.self)
              await send(.internal(.imageDataLoaded(data)))
            }

          case .createPromiseTapped:
            guard let info = state.extractedInfo else { return .none }
            return .send(.delegate(.createPromiseRequested(info)))

          case .clearTapped:
            state.inputText = ""
            state.extractedInfo = nil
            state.extractionError = nil
            state.isExtracting = false
            state.isExtractingFromImage = false
            return .none

          case .errorDismissed:
            state.extractionError = nil
            return .none

          case .loadSharedContent:
            return .run { send in
              let suiteName = LiveActivityIntentKey.suiteName
              guard let defaults = UserDefaults(suiteName: suiteName) else { return }

              let contentType = defaults.string(forKey: AppConstants.ShareExtension.contentTypeKey)
              let sharedText = defaults.string(forKey: AppConstants.ShareExtension.sharedTextKey)
              let sharedImageData = defaults.data(forKey: AppConstants.ShareExtension.sharedImageDataKey)
              let timestamp = defaults.double(forKey: AppConstants.ShareExtension.sharedTimestampKey)

              // 읽은 후 즉시 정리
              defaults.removeObject(forKey: AppConstants.ShareExtension.contentTypeKey)
              defaults.removeObject(forKey: AppConstants.ShareExtension.sharedTextKey)
              defaults.removeObject(forKey: AppConstants.ShareExtension.sharedImageDataKey)
              defaults.removeObject(forKey: AppConstants.ShareExtension.sharedTimestampKey)

              // 타임스탬프 검증 (5분 이내만 유효)
              let isStale = Date().timeIntervalSince1970 - timestamp > 300
              guard !isStale else { return }

              await send(.internal(.sharedContentLoaded(
                type: contentType,
                text: sharedText,
                imageData: sharedImageData
              )))
            }
          }

        case .internal(let internalAction):
          switch internalAction {
          case .textExtractionResult(.success(let info)):
            state.isExtracting = false
            state.extractedInfo = info
            return .none

          case .textExtractionResult(.failure):
            state.isExtracting = false
            state.extractionError = LocalizedStrings.QuickPromise.errorTextAnalysis
            return .none

          case .imageDataLoaded(let data):
            guard let data else {
              state.isExtractingFromImage = false
              state.extractionError = LocalizedStrings.QuickPromise.errorImageLoad
              return .none
            }
            return .run { [extractionClient] send in
              do {
                let info = try await extractionClient.extractFromImage(data)
                await send(.internal(.imageExtractionResult(.success(info))))
              } catch {
                await send(.internal(.imageExtractionResult(.failure(error))))
              }
            }

          case .imageExtractionResult(.success(let info)):
            state.isExtractingFromImage = false
            state.extractedInfo = info
            state.inputText = info.rawText
            return .none

          case .imageExtractionResult(.failure):
            state.isExtractingFromImage = false
            state.extractionError = LocalizedStrings.QuickPromise.errorImageExtraction
            return .none

          case .sharedContentLoaded(let type, let text, let imageData):
            switch type {
            case "text":
              guard let text, !text.isEmpty else { return .none }
              state.inputText = text
              state.isExtracting = true
              state.extractionError = nil
              return .run { [extractionClient] send in
                do {
                  let info = try await extractionClient.extractFromText(text)
                  await send(.internal(.textExtractionResult(.success(info))))
                } catch {
                  await send(.internal(.textExtractionResult(.failure(error))))
                }
              }

            case "image":
              guard let imageData, !imageData.isEmpty else { return .none }
              state.isExtractingFromImage = true
              state.extractionError = nil
              return .run { [extractionClient] send in
                do {
                  let info = try await extractionClient.extractFromImage(imageData)
                  await send(.internal(.imageExtractionResult(.success(info))))
                } catch {
                  await send(.internal(.imageExtractionResult(.failure(error))))
                }
              }

            default:
              return .none
            }
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
