/*

 PopularimeterFrame.swift
 SwiftTaggerID3

 Copyright ©2024 Spencer Curtis. All rights reserved.

 */

/*
 The popularimeter frame contains a rating (0-255) and an optional play count.
 The frame is keyed by email address to allow multiple ratings per file.

 <Header for 'Popularimeter', ID: "POPM">
 Email to user   <text string> $00
 Rating          $xx
 Counter         $xx xx xx xx (xx ...)

 The rating is 1-255 where 1 is lowest and 255 is highest. 0 is unknown.
 Common mapping to 5-star scale (Windows Media Player/MediaMonkey standard):
   1 = ★ (1 star)
   64 = ★★ (2 stars)
   128 = ★★★ (3 stars)
   196 = ★★★★ (4 stars)
   255 = ★★★★★ (5 stars)

 The counter is optional and stores the play count as a big-endian integer.
 */

import Foundation

/// A type representing an ID3 POPM (Popularimeter) frame
class PopularimeterFrame: Frame {
    override var description: String {
        if let count = playCount {
            return "Rating: \(rating) (\(starRating) stars), Plays: \(count), Email: \(email)"
        } else {
            return "Rating: \(rating) (\(starRating) stars), Email: \(email)"
        }
    }

    /// The email address identifying the rater (can be empty)
    var email: String

    /// The rating value (0-255)
    /// 0 = unknown, 1-255 = rating where 255 is highest
    var rating: UInt8

    /// The play count (optional)
    var playCount: UInt64?

    /// Convenience property: rating converted to 0-5 star scale
    var starRating: Int {
        get {
            Self.byteToStars(rating)
        }
        set {
            rating = Self.starsToByte(newValue)
        }
    }

    // MARK: - Star Rating Conversion

    /// Convert 0-255 byte value to 0-5 star rating (Windows Media Player standard)
    static func byteToStars(_ byte: UInt8) -> Int {
        switch byte {
        case 0: return 0
        case 1...31: return 1
        case 32...95: return 2
        case 96...159: return 3
        case 160...223: return 4
        case 224...255: return 5
        default: return 0
        }
    }

    /// Convert 0-5 star rating to byte value (Windows Media Player standard)
    static func starsToByte(_ stars: Int) -> UInt8 {
        switch stars {
        case 0: return 0
        case 1: return 1
        case 2: return 64
        case 3: return 128
        case 4: return 196
        case 5: return 255
        default: return 0
        }
    }

    // MARK: - Frame Parsing

    init(
        identifier: FrameIdentifier,
        version: Version,
        size: Int,
        flags: Data,
        payload: Data
    ) throws {
        var data = payload

        // Parse email (null-terminated Latin-1 string)
        self.email = data.extractNullTerminatedString(.isoLatin1) ?? ""

        // Parse rating (single byte)
        guard !data.isEmpty else {
            throw Mp3FileError.InvalidFrameData
        }
        self.rating = data.removeFirst()

        // Parse optional play count (remaining bytes as big-endian integer)
        if !data.isEmpty {
            self.playCount = data.bigEndianUInt64
        } else {
            self.playCount = nil
        }

        super.init(
            identifier: identifier,
            version: version,
            size: size,
            flags: flags
        )
    }

    // MARK: - Frame Encoding

    override var contentData: Data {
        var data = Data()

        // Email (null-terminated Latin-1)
        data.append(email.attemptTerminatedStringEncoding(.isoLatin1))

        // Rating (single byte)
        data.append(rating)

        // Play count (optional, variable-length big-endian integer)
        if let count = playCount {
            data.append(count.bigEndianData)
        }

        return data
    }

    override var frameKey: FrameKey {
        .popularimeter(email: email)
    }

    // MARK: - Frame Creation

    /// Create a new PopularimeterFrame
    init(
        version: Version,
        email: String = "",
        rating: UInt8 = 0,
        playCount: UInt64? = nil
    ) {
        self.email = email
        self.rating = rating
        self.playCount = playCount

        // Calculate size
        var size = email.attemptTerminatedStringEncoding(.isoLatin1).count + 1 // email + rating byte
        if let count = playCount {
            size += count.bigEndianData.count
        }

        let flags = version.defaultFlags
        super.init(
            identifier: .popularimeter,
            version: version,
            size: size,
            flags: flags
        )
    }

    /// Create a new PopularimeterFrame with star rating (0-5)
    convenience init(
        version: Version,
        email: String = "",
        starRating: Int,
        playCount: UInt64? = nil
    ) {
        self.init(
            version: version,
            email: email,
            rating: Self.starsToByte(starRating),
            playCount: playCount
        )
    }
}

// MARK: - Data Extensions for Big-Endian Integer Handling

private extension Data {
    /// Parse remaining bytes as a big-endian unsigned integer (variable length)
    var bigEndianUInt64: UInt64 {
        var result: UInt64 = 0
        for byte in self {
            result = (result << 8) | UInt64(byte)
        }
        return result
    }
}

private extension UInt64 {
    /// Encode as minimal big-endian data (strips leading zero bytes, minimum 4 bytes)
    var bigEndianData: Data {
        // Always use at least 4 bytes for compatibility
        var value = self.bigEndian
        var data = Data(bytes: &value, count: MemoryLayout<UInt64>.size)

        // Remove leading zero bytes but keep at least 4 bytes
        while data.count > 4 && data.first == 0 {
            data.removeFirst()
        }

        return data
    }
}

// MARK: - Tag Extension

extension Tag {

    /// Get the first popularimeter frame (any email)
    private func getPopularimeter() -> PopularimeterFrame? {
        for (key, frame) in frames {
            if case .popularimeter = key, let popmFrame = frame as? PopularimeterFrame {
                return popmFrame
            }
        }
        return nil
    }

    /// Get popularimeter frame for specific email
    private func getPopularimeter(email: String) -> PopularimeterFrame? {
        let key = FrameKey.popularimeter(email: email)
        return frames[key] as? PopularimeterFrame
    }

    /// Set popularimeter frame
    private mutating func setPopularimeter(
        email: String = "",
        rating: UInt8,
        playCount: UInt64? = nil
    ) {
        let frame = PopularimeterFrame(
            version: version,
            email: email,
            rating: rating,
            playCount: playCount
        )
        frames[frame.frameKey] = frame
    }

    /// Remove popularimeter frame for specific email
    private mutating func removePopularimeter(email: String = "") {
        let key = FrameKey.popularimeter(email: email)
        frames[key] = nil
    }

    // MARK: - Public API

    /// Rating (0-255) from the first POPM frame. Getter returns nil if no frame exists.
    public var rating: UInt8? {
        get {
            getPopularimeter()?.rating
        }
        set {
            if let value = newValue {
                let existing = getPopularimeter()
                setPopularimeter(
                    email: existing?.email ?? "",
                    rating: value,
                    playCount: existing?.playCount
                )
            } else {
                // Remove all popularimeter frames
                let keysToRemove = frames.keys.filter {
                    if case .popularimeter = $0 { return true }
                    return false
                }
                for key in keysToRemove {
                    frames[key] = nil
                }
            }
        }
    }

    /// Star rating (0-5) converted from the POPM rating byte
    public var starRating: Int? {
        get {
            getPopularimeter()?.starRating
        }
        set {
            if let value = newValue {
                let existing = getPopularimeter()
                setPopularimeter(
                    email: existing?.email ?? "",
                    rating: PopularimeterFrame.starsToByte(value),
                    playCount: existing?.playCount
                )
            } else {
                rating = nil
            }
        }
    }

    /// Play count from the first POPM frame
    public var playCount: UInt64? {
        get {
            getPopularimeter()?.playCount
        }
        set {
            let existing = getPopularimeter()
            if let count = newValue {
                setPopularimeter(
                    email: existing?.email ?? "",
                    rating: existing?.rating ?? 0,
                    playCount: count
                )
            } else if let existing = existing {
                // Keep the rating but remove play count
                setPopularimeter(
                    email: existing.email,
                    rating: existing.rating,
                    playCount: nil
                )
            }
        }
    }

    /// Email from the first POPM frame (identifies the rater)
    public var ratingEmail: String? {
        get {
            getPopularimeter()?.email
        }
        set {
            if let email = newValue {
                let existing = getPopularimeter()
                // Remove old frame and create new one with updated email
                if let old = existing {
                    removePopularimeter(email: old.email)
                }
                setPopularimeter(
                    email: email,
                    rating: existing?.rating ?? 0,
                    playCount: existing?.playCount
                )
            }
        }
    }
}
