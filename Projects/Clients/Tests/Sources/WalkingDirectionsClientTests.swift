import ComposableArchitecture
import Testing
@testable import Clients

// MARK: - WalkingDirectionsResult 프로퍼티 테스트

@Suite("WalkingDirectionsResult 프로퍼티 테스트")
struct WalkingDirectionsResultTests {

  @Test("distanceMeters, durationMinutes, routePoints가 올바르게 저장됨")
  func init_storesPropertiesCorrectly() {
    let result = WalkingDirectionsResult(
      distanceMeters: 1200,
      durationMinutes: 15,
      routePoints: [[127.0276, 37.4981], [127.0250, 37.5000]]
    )

    #expect(result.distanceMeters == 1200)
    #expect(result.durationMinutes == 15)
    #expect(result.routePoints.count == 2)
    #expect(result.routePoints[0] == [127.0276, 37.4981])
    #expect(result.routePoints[1] == [127.0250, 37.5000])
  }

  @Test("routePoints가 빈 배열이어도 생성 가능")
  func init_withEmptyRoutePoints_succeeds() {
    let result = WalkingDirectionsResult(
      distanceMeters: 0,
      durationMinutes: 0,
      routePoints: []
    )

    #expect(result.distanceMeters == 0)
    #expect(result.durationMinutes == 0)
    #expect(result.routePoints.isEmpty)
  }

  @Test("같은 값으로 생성된 두 결과는 동일하다 (Equatable)")
  func equatable_sameValues_areEqual() {
    let result1 = WalkingDirectionsResult(
      distanceMeters: 500,
      durationMinutes: 7,
      routePoints: [[126.9236, 37.5567]]
    )
    let result2 = WalkingDirectionsResult(
      distanceMeters: 500,
      durationMinutes: 7,
      routePoints: [[126.9236, 37.5567]]
    )

    #expect(result1 == result2)
  }

  @Test("distanceMeters가 다르면 두 결과는 다르다 (Equatable)")
  func equatable_differentDistance_areNotEqual() {
    let result1 = WalkingDirectionsResult(
      distanceMeters: 500,
      durationMinutes: 7,
      routePoints: []
    )
    let result2 = WalkingDirectionsResult(
      distanceMeters: 600,
      durationMinutes: 7,
      routePoints: []
    )

    #expect(result1 != result2)
  }
}

// MARK: - WalkingDirectionsClient 인터페이스 테스트

@Suite("WalkingDirectionsClient 인터페이스 테스트")
struct WalkingDirectionsClientTests {

  // MARK: - 정상 결과 반환

  @Test("getWalkingDirections가 정상 결과를 반환하는 경우")
  func getWalkingDirections_success_returnsResult() async throws {
    let expected = WalkingDirectionsResult(
      distanceMeters: 2500,
      durationMinutes: 32,
      routePoints: [
        [127.0276, 37.4981],
        [127.0250, 37.5000],
        [127.0230, 37.5050]
      ]
    )

    let client = WalkingDirectionsClient(
      getWalkingDirections: { _, _, _, _ in expected }
    )

    let result = try await client.getWalkingDirections(37.4981, 127.0276, 37.5567, 126.9236)

    #expect(result == expected)
    #expect(result.distanceMeters == 2500)
    #expect(result.durationMinutes == 32)
    #expect(result.routePoints.count == 3)
  }

  @Test("getWalkingDirections가 출발/도착 좌표를 올바르게 전달하는 경우")
  func getWalkingDirections_passesCoordinatesCorrectly() async throws {
    let capturedCoordinates = LockIsolated<(Double, Double, Double, Double)?>(nil)

    let client = WalkingDirectionsClient(
      getWalkingDirections: { fromLat, fromLng, toLat, toLng in
        capturedCoordinates.setValue((fromLat, fromLng, toLat, toLng))
        return WalkingDirectionsResult(distanceMeters: 0, durationMinutes: 0, routePoints: [])
      }
    )

    _ = try await client.getWalkingDirections(37.4981, 127.0276, 37.5567, 126.9236)

    let coords = capturedCoordinates.value
    #expect(coords?.0 == 37.4981)
    #expect(coords?.1 == 127.0276)
    #expect(coords?.2 == 37.5567)
    #expect(coords?.3 == 126.9236)
  }

  // MARK: - 에러 핸들링

  @Test("getWalkingDirections가 noRouteFound 에러를 던지는 경우")
  func getWalkingDirections_noRoute_throwsError() async {
    let client = WalkingDirectionsClient(
      getWalkingDirections: { _, _, _, _ in
        throw WalkingDirectionsError.noRouteFound
      }
    )

    await #expect(throws: WalkingDirectionsError.noRouteFound) {
      _ = try await client.getWalkingDirections(0, 0, 0, 0)
    }
  }

  @Test("getWalkingDirections가 임의의 에러를 던지는 경우")
  func getWalkingDirections_arbitraryError_propagatesError() async {
    struct NetworkError: Error {}

    let client = WalkingDirectionsClient(
      getWalkingDirections: { _, _, _, _ in
        throw NetworkError()
      }
    )

    await #expect(throws: NetworkError.self) {
      _ = try await client.getWalkingDirections(0, 0, 0, 0)
    }
  }

  // MARK: - testValue (unimplemented)

  @Test("testValue는 WalkingDirectionsClient 타입으로 생성된다")
  func testValue_isWalkingDirectionsClientType() {
    // @DependencyClient의 testValue는 unimplemented 클로저를 가진 인스턴스를 반환
    // unimplemented는 호출 시 테스트 이슈를 기록하는 방식으로 동작하며
    // 테스트에서 의도치 않게 호출되는 것을 방지하는 안전망 역할을 함
    let client = WalkingDirectionsClient.testValue
    #expect(type(of: client) == WalkingDirectionsClient.self)
  }
}

// MARK: - WalkingDirectionsClient previewValue 테스트

@Suite("WalkingDirectionsClient previewValue 테스트")
struct WalkingDirectionsClientPreviewTests {

  @Test("previewValue의 getWalkingDirections가 고정 결과를 반환한다")
  func previewValue_returnsFixedResult() async throws {
    let client = WalkingDirectionsClient.previewValue

    let result = try await client.getWalkingDirections(0, 0, 0, 0)

    #expect(result.distanceMeters == 2500)
    #expect(result.durationMinutes == 32)
    #expect(result.routePoints.count == 4)
  }
}

// MARK: - WalkingDirectionsError 테스트

@Suite("WalkingDirectionsError 테스트")
struct WalkingDirectionsErrorTests {

  @Test("noRouteFound 에러는 Error 프로토콜을 준수한다")
  func noRouteFound_conformsToError() {
    let error: any Error = WalkingDirectionsError.noRouteFound
    #expect(error is WalkingDirectionsError)
  }
}
