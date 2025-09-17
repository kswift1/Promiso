import ProjectDescription

public enum FirebaseModule: String, CaseIterable {
  case auth         = "FirebaseAuth"
  case firestore    = "FirebaseFirestore"
  case messaging    = "FirebaseMessaging"
  case crashlytics  = "FirebaseCrashlytics"
  case analytics    = "FirebaseAnalytics"
  case remoteConfig = "FirebaseRemoteConfig"
  case storage      = "FirebaseStorage"

  var dep: TargetDependency { .external(name: rawValue) }
}
