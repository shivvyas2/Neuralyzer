import Foundation

/// 64 bit difference hash of a 9x8 grayscale image: one bit per pixel, set when it is
/// brighter than its right neighbor. Copies of a photo hash within a few bits of each other.
public func differenceHash(gray: [UInt8], width: Int, height: Int) -> UInt64 {
    precondition(width == 9 && height == 8 && gray.count == 72)
    var hash: UInt64 = 0
    for y in 0..<8 {
        for x in 0..<8 {
            hash <<= 1
            if gray[y * 9 + x] > gray[y * 9 + x + 1] { hash |= 1 }
        }
    }
    return hash
}

/// Variance of the Laplacian of a grayscale image. Sharp photos have strong edges and a high
/// value; blurry ones score low.
public func laplacianVariance(gray: [UInt8], width: Int, height: Int) -> Double {
    guard width > 2, height > 2, gray.count == width * height else { return 0 }
    var values: [Double] = []
    values.reserveCapacity((width - 2) * (height - 2))
    for y in 1..<(height - 1) {
        for x in 1..<(width - 1) {
            let c = Double(gray[y * width + x])
            let l = Double(gray[y * width + x - 1]) + Double(gray[y * width + x + 1])
                + Double(gray[(y - 1) * width + x]) + Double(gray[(y + 1) * width + x]) - 4 * c
            values.append(l)
        }
    }
    let mean = values.reduce(0, +) / Double(values.count)
    return values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
}
