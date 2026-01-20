import SwiftUI
import Clients
import ComposableArchitecture
import ResourceKit

// MARK: - Step 2 Content View
struct CreatePromiseStep2View: View {
  let store: StoreOf<CreatePromise.Feature>
  
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          // 헤더
          CreatePromiseStep.second.headerView
          
          // 시작 날짜/시간
          StartDateTimeSection(store: store, scrollProxy: proxy)
            .id("startDateTime")
          
          // 종료 날짜/시간 (선택)
          EndDateTimeSection(store: store, scrollProxy: proxy)
            .id("endDateTime")
          
          // TODO: Phase2 장소 추가
          // 장소 (선택)
//          LocationSection(store: store)
          
          // 최소 참가 인원
          MinimumParticipantsSection(store: store, scrollProxy: proxy)
        }
        .padding(16)
      }
    }
  }
}

// MARK: - Location Section
struct LocationSection: View {
  let store: StoreOf<CreatePromise.Feature>
  @State private var showLocationPicker = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "mappin.and.ellipse")
          .foregroundColor(Color.pmindigo.n500)
        Text("장소")
          .font(.system(size: 16, weight: .semibold))
        Text("(선택)")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
      
      Button(action: {
        showLocationPicker = true
      }) {
        HStack(spacing: 12) {
          if let location = store.promise.location {
            VStack(alignment: .leading, spacing: 4) {
              Text(location.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

              if let address = location.address {
                Text(address)
                  .font(.system(size: 14))
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            }
          } else {
            Text("장소를 검색하거나 입력하세요")
              .font(.system(size: 16))
              .foregroundColor(.secondary)
          }

          Spacer()

          Image(systemName: store.promise.location != nil ? "pencil" : "magnifyingglass")
            .foregroundColor(Color.pmindigo.n500)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
      }
      
      // 안내 메시지
      HStack(spacing: 6) {
        Image(systemName: "lightbulb.fill")
          .font(.system(size: 12))
        Text("장소를 입력하면 참석자들이 길찾기를 쉽게 할 수 있습니다")
          .font(.system(size: 13))
      }
      .foregroundColor(Color.pmindigo.n500)
      .padding(.horizontal, 4)
    }
    .sheet(isPresented: $showLocationPicker) {
      //      LocationPickerView(
      //        selectedLocation: Binding(
      //          get: { store.promiseProposal.place },
      //          set: { /*store.send(.setLocation($0))*/ }
      //        )
      //      )
    }
  }
}


// MARK: - Location Picker View
//struct LocationPickerView: View {
//  @Environment(\.dismiss) var dismiss
//  @Binding var selectedLocation: Location?
//  @State private var searchText = ""
//
//  // 목 데이터
//  private let sampleLocations = [
//    Location(
//      name: "CGV 강남",
//      address: "서울특별시 강남구 강남대로 438",
//      latitude: 37.501234,
//      longitude: 127.026789,
//      placeId: nil
//    ),
//    Location(
//      name: "스타벅스 역삼점",
//      address: "서울특별시 강남구 테헤란로 123",
//      latitude: nil,
//      longitude: nil,
//      placeId: nil
//    ),
//    Location(
//      name: "성수동 카페거리",
//      address: "서울특별시 성동구 성수동",
//      latitude: nil,
//      longitude: nil,
//      placeId: nil
//    ),
//  ]
//
//  var filteredLocations: [Location] {
//    if searchText.isEmpty {
//      return sampleLocations
//    }
//    return sampleLocations.filter { location in
//      location.name.localizedCaseInsensitiveContains(searchText) ||
//      (location.address?.localizedCaseInsensitiveContains(searchText) ?? false)
//    }
//  }
//
//  var body: some View {
//    NavigationView {
//      VStack(spacing: 0) {
//        // 검색바
//        HStack {
//          Image(systemName: "magnifyingglass")
//            .foregroundColor(.secondary)
//
//          TextField("장소 검색", text: $searchText)
//            .textFieldStyle(.plain)
//
//          if !searchText.isEmpty {
//            Button(action: { searchText = "" }) {
//              Image(systemName: "xmark.circle.fill")
//                .foregroundColor(.secondary)
//            }
//          }
//        }
//        .padding(12)
//        .background(Color(.systemGray6))
//        .clipShape(RoundedRectangle(cornerRadius: 10))
//        .padding(16)
//
//        Divider()
//
//        // 검색 결과
//        ScrollView {
//          VStack(spacing: 0) {
//            ForEach(filteredLocations, id: \.name) { location in
//              Button(action: {
//                selectedLocation = location
//                dismiss()
//              }) {
//                HStack(spacing: 12) {
//                  Image(systemName: "mappin.circle.fill")
//                    .font(.system(size: 24))
//                    .foregroundColor(Color.pmindigo.n500)
//
//                  VStack(alignment: .leading, spacing: 4) {
//                    Text(location.name)
//                      .font(.system(size: 16, weight: .medium))
//                      .foregroundColor(.primary)
//
//                    if let address = location.address {
//                      Text(address)
//                        .font(.system(size: 14))
//                        .foregroundColor(.secondary)
//                        .lineLimit(1)
//                    }
//                  }
//
//                  Spacer()
//                }
//                .padding(16)
//              }
//
//              Divider()
//                .padding(.leading, 52)
//            }
//
//            if filteredLocations.isEmpty {
//              VStack(spacing: 12) {
//                Image(systemName: "magnifyingglass")
//                  .font(.system(size: 48))
//                  .foregroundColor(.secondary)
//
//                Text("검색 결과가 없습니다")
//                  .font(.system(size: 16))
//                  .foregroundColor(.secondary)
//              }
//              .frame(maxWidth: .infinity)
//              .padding(.vertical, 60)
//            }
//          }
//        }
//      }
//      .navigationTitle("장소 선택")
//      .navigationBarTitleDisplayMode(.inline)
//      .toolbar {
//        ToolbarItem(placement: .navigationBarLeading) {
//          Button("취소") {
//            dismiss()
//          }
//        }
//      }
//    }
//  }
//}

//// MARK: - Previews
//#Preview("Step 2 - 기본 상태") {
//  CreatePromiseStep2View(
//    store: Store(
//      initialState: CreatePromise.Feature.State(
//        currentStep: .second,
//        promiseProposal: PromiseProposal(
//          title: "영화 관람",
//          emoji: "🍿",
//          group: .init(
//            id: "",
//            emoji: "",
//            title: "",
//            memberCount: 3
//          ),
//          startedAt: Date().addingTimeInterval(3600 * 2),
//          // 2시간 후
//          minimumParticipants: 2
//        ),
//        groupListState: .loaded([
//          GroupModel(id: "1", emoji: "🎓", title: "대학 친구들", memberCount: 4)
//        ])
//      )
//    ) {
//      CreatePromise.Feature()
//    }
//  )
//  .padding()
//}
//
//#Preview("Step 2 - 종료 시간 포함") {
//  CreatePromiseStep2View(
//    store: Store(
//      initialState: CreatePromise.Feature.State(
//        currentStep: .second,
//        promiseProposal: PromiseProposal(
//          title: "영화 관람",
//          emoji: "🍿",
//          groupID: "1",
//          startedAt: Date().addingTimeInterval(3600 * 2),
//          endedAt: Date().addingTimeInterval(3600 * 4), // 4시간 후
//          minimumParticipants: 3
//        ),
//        groupListState: .loaded([
//          GroupModel(id: "1", emoji: "🎓", title: "대학 친구들", memberCount: 5)
//        ])
//      )
//    ) {
//      CreatePromise.Feature()
//    }
//  )
//  .padding()
//}
//
////#Preview("Step 2 - 장소 포함") {
////  CreatePromiseStep2View(
////    store: Store(
////      initialState: CreatePromise.Feature.State(
////        currentStep: .second,
////        promiseProposal: PromiseProposal(
////          title: "카페 미팅",
////          emoji: "☕",
////          groupID: "1",
////          startedAt: Date().addingTimeInterval(3600 * 3),
////          location: Location(
////            name: "CGV 강남",
////            address: "서울특별시 강남구 강남대로 438",
////            latitude: 37.501234,
////            longitude: 127.026789,
////            placeId: nil
////          ),
////          minimumParticipants: 2
////        ),
////        groupListState: .loaded([
////          GroupModel(id: "1", name: "개발팀", emoji: "💼", colorHex: "3B82F6", memberCount: 8)
////        ])
////      )
////    ) {
////      CreatePromise.Feature()
////    }
////  )
////  .padding()
////}
//
//#Preview("Step 2 - 1시간 이내 경고") {
//  CreatePromiseStep2View(
//    store: Store(
//      initialState: CreatePromise.Feature.State(
//        currentStep: .second,
//        promiseProposal: PromiseProposal(
//          title: "긴급 회의",
//          emoji: "💼",
//          groupID: "1",
//          startedAt: Date().addingTimeInterval(1800), // 30분 후
//          minimumParticipants: 2
//        ),
//        groupListState: .loaded([
//          GroupModel(id: "1", emoji: "💼", title: "개발팀", memberCount: 6)
//        ])
//      )
//    ) {
//      CreatePromise.Feature()
//    }
//  )
//  .padding()
//}
//
//#Preview("Step 2 - 최대 인원 선택") {
//  CreatePromiseStep2View(
//    store: Store(
//      initialState: CreatePromise.Feature.State(
//        currentStep: .second,
//        promiseProposal: PromiseProposal(
//          title: "팀 전체 회의",
//          emoji: "💼",
//          groupID: "1",
//          startedAt: Date().addingTimeInterval(3600 * 24), // 하루 후
//          minimumParticipants: 4 // 최대와 같음
//        ),
//        groupListState: .loaded([
//          GroupModel(id: "1", emoji: "👥", title: "소규모 팀", memberCount: 4)
//        ])
//      )
//    ) {
//      CreatePromise.Feature()
//    }
//  )
//  .padding()
//}
//
//#Preview("Location Picker") {
////  LocationPickerView(
////    selectedLocation: .constant(nil)
////  )
//}
//
//#Preview("전체 화면 - Step 2") {
//  CreatePromise.RootView(
//    store: Store(
//      initialState: CreatePromise.Feature.State(
//        currentStep: .second,
//        promiseProposal: PromiseProposal(
//          title: "영화 관람",
//          emoji: "🍿",
//          groupID: "1",
//          startedAt: Date().addingTimeInterval(3600 * 2),
//          minimumParticipants: 2
//        ),
//        groupListState: .loaded([
//          GroupModel(id: "1", emoji: "🎓", title: "대학 친구들", memberCount: 4),
//          GroupModel(id: "2", emoji: "💼", title: "개발팀", memberCount: 8)
//        ])
//      )
//    ) {
//      CreatePromise.Feature()
//    }
//  )
//}
