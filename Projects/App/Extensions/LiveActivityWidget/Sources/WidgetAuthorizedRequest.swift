import Foundation
import os.log
import PromisoShared

private let logger = Logger(subsystem: "com.promiso.widget", category: "WidgetAuthorizedRequest")

func performAuthenticatedWidgetPost(
  to url: URL,
  userId: String,
  body: Data,
  logContext: String
) async -> Bool {
  let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName)
  let widgetToken = defaults?.string(forKey: LiveActivityIntentKey.widgetTokenKey)
  let accessToken = defaults?.string(forKey: LiveActivityIntentKey.authTokenKey)
  let deviceId = defaults?.string(forKey: LiveActivityIntentKey.widgetDeviceIdKey)

  guard let primaryToken = widgetToken ?? accessToken else {
    logger.error("\(logContext, privacy: .public): missing auth token")
    return false
  }

  let primaryStatus = await sendWidgetRequest(
    to: url,
    userId: userId,
    authToken: primaryToken,
    deviceId: deviceId,
    body: body,
    logContext: logContext
  )
  if primaryStatus == 200 {
    return true
  }

  if primaryStatus == 401,
     let widgetToken,
     primaryToken == widgetToken,
     let accessToken,
     accessToken != widgetToken {
    logger.info("\(logContext, privacy: .public): widget token 401 -> access token fallback")
    let fallbackStatus = await sendWidgetRequest(
      to: url,
      userId: userId,
      authToken: accessToken,
      deviceId: deviceId,
      body: body,
      logContext: logContext
    )
    return fallbackStatus == 200
  }

  return false
}

private func sendWidgetRequest(
  to url: URL,
  userId: String,
  authToken: String,
  deviceId: String?,
  body: Data,
  logContext: String
) async -> Int? {
  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  request.setValue(userId, forHTTPHeaderField: "X-User-Id")
  request.setValue(authToken, forHTTPHeaderField: "X-Auth-Token")
  request.httpBody = body

  if let deviceId {
    request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
  }

  do {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      logger.error("\(logContext, privacy: .public): non-http response")
      return nil
    }

    if httpResponse.statusCode != 200 {
      let bodyText = String(data: data, encoding: .utf8) ?? ""
      logger.error("\(logContext, privacy: .public) failed(\(httpResponse.statusCode)): \(bodyText.prefix(200), privacy: .public)")
    }

    return httpResponse.statusCode
  } catch {
    logger.error("\(logContext, privacy: .public) error: \(error.localizedDescription, privacy: .public)")
    return nil
  }
}
