// TestEmulatorView.swift

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage

struct TestEmulatorView: View {
  @State private var result: String = "Ready to test"
  @State private var isLoading: Bool = false
  
  var body: some View {
    VStack(spacing: 20) {
      Text("🎮 Emulator Test")
        .font(.largeTitle)
        .bold()
      
      Text(result)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
      
      VStack(spacing: 12) {
        // 1. Auth 테스트
        Button("Test Auth") {
          testAuth()
        }
        .buttonStyle(.borderedProminent)
        
        // 2. Firestore 테스트
        Button("Test Firestore") {
          testFirestore()
        }
        .buttonStyle(.borderedProminent)
        
        // 3. Functions 테스트
        Button("Test Functions") {
          testFunctions()
        }
        .buttonStyle(.borderedProminent)
        
        // 4. Storage 테스트
        Button("Test Storage") {
          testStorage()
        }
        .buttonStyle(.borderedProminent)
      }
      
      if isLoading {
        ProgressView()
      }
    }
    .padding()
  }
  
  // MARK: - Test Functions
  
  func testAuth() {
    isLoading = true
    result = "Testing Auth..."
    
    Task {
      do {
        // 익명 로그인
        let authResult = try await Auth.auth().signInAnonymously()
        await MainActor.run {
          result = "✅ Auth Success!\nUID: \(authResult.user.uid)"
          isLoading = false
        }
      } catch {
        await MainActor.run {
          result = "❌ Auth Error: \(error.localizedDescription)"
          isLoading = false
        }
      }
    }
  }
  
  func testFirestore() {
    isLoading = true
    result = "Testing Firestore..."
    
    Task {
      do {
        let db = Firestore.firestore()
        
        // 테스트 데이터 쓰기
        try await db.collection("test").document("doc1").setData([
          "message": "Hello Emulator!",
          "timestamp": FieldValue.serverTimestamp()
        ])
        
        // 읽기
        let doc = try await db.collection("test").document("doc1").getDocument()
        let message = doc.data()?["message"] as? String ?? ""
        
        await MainActor.run {
          result = "✅ Firestore Success!\nMessage: \(message)"
          isLoading = false
        }
      } catch {
        await MainActor.run {
          result = "❌ Firestore Error: \(error.localizedDescription)"
          isLoading = false
        }
      }
    }
  }
  
  func testFunctions() {
    isLoading = true
    result = "Testing Functions..."
    
    Task {
      do {
        let functions = Functions.functions()
        let result = try await functions.httpsCallable("testCallable").call([
          "name": "iOS Tester"
        ])
        
        guard let data = result.data as? [String: Any],
              let message = data["message"] as? String else {
          throw NSError(domain: "", code: -1)
        }
        
        await MainActor.run {
          self.result = "✅ Functions Success!\n\(message)"
          isLoading = false
        }
      } catch {
        await MainActor.run {
          result = "❌ Functions Error: \(error.localizedDescription)"
          isLoading = false
        }
      }
    }
  }
  
  func testStorage() {
    isLoading = true
    result = "Testing Storage..."
    
    Task {
      do {
        let storage = Storage.storage()
        let storageRef = storage.reference().child("test/test.txt")
        
        // 업로드
        let testData = "Hello Storage!".data(using: .utf8)!
        _ = try await storageRef.putDataAsync(testData)
        
        // 다운로드 URL
        let url = try await storageRef.downloadURL()
        
        await MainActor.run {
          result = "✅ Storage Success!\nURL: \(url.absoluteString)"
          isLoading = false
        }
      } catch {
        await MainActor.run {
          result = "❌ Storage Error: \(error.localizedDescription)"
          isLoading = false
        }
      }
    }
  }
}

#Preview {
  TestEmulatorView()
}
