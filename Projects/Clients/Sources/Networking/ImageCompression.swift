//
//  Image Compression.swift
//  Infrastructure
//
//  Created by 김성원 on 12/13/25.
//

import Foundation
import UIKit

/// 원본 사진을 앱에서 보기 좋은 수준으로 리사이즈+압축해 업로드 크기를 줄인다.
public func compressImageDataForUpload(_ data: Data, maxDimension: CGFloat = 1024, compressionQuality: CGFloat = 0.7) -> Data? {
  guard let image = UIImage(data: data) else { return nil }
  
  let longestSide = max(image.size.width, image.size.height)
  let scale = longestSide > maxDimension ? maxDimension / longestSide : 1
  let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
  
  let renderer = UIGraphicsImageRenderer(size: targetSize)
  let resizedData = renderer.jpegData(withCompressionQuality: compressionQuality) { _ in
    image.draw(in: CGRect(origin: .zero, size: targetSize))
  }
  
  return resizedData
}
