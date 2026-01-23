/*
 UpdateRealWorldTestFiles.swift
 SwiftTaggerID3

 One-time utility to add BPM and POPM (star rating) to PodCenter's RealWorld test MP3 files.
 Run with: swift test --filter UpdateRealWorldTestFiles
*/

import XCTest
@testable import SwiftTaggerID3

class UpdateRealWorldTestFiles: XCTestCase {

    let testFilesDir = "/Users/spencercurtis/Documents/PodCenter/PodCenterTests/TestResources/Audio/RealWorld"

    /// Add BPM=120 and star rating=4 to all MP3 test files
    func testAddBPMAndRatingToMP3Files() throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: testFilesDir)

        let mp3Files = contents.filter { $0.hasSuffix(".mp3") }

        for fileName in mp3Files {
            let filePath = (testFilesDir as NSString).appendingPathComponent(fileName)
            let url = URL(fileURLWithPath: filePath)

            print("Processing: \(fileName)")

            let mp3File = try Mp3File(location: url)
            var tag = try Tag(mp3File: mp3File)

            // Add BPM if not present
            if tag.bpm == nil {
                tag.bpm = 120
                print("  Added BPM: 120")
            } else {
                print("  BPM already set: \(tag.bpm!)")
            }

            // Add star rating (4 stars) via POPM if not present
            if tag.starRating == nil || tag.starRating == 0 {
                tag.starRating = 4
                print("  Added star rating: 4 (byte value: \(tag.rating ?? 0))")
            } else {
                print("  Star rating already set: \(tag.starRating!)")
            }

            // Write back to file
            try mp3File.write(tag: &tag, version: .v2_4, outputLocation: url)
            print("  Saved successfully")
        }

        print("\nDone! Updated \(mp3Files.count) MP3 files")
    }

    /// Verify the updates were applied
    func testVerifyMP3Metadata() throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: testFilesDir)

        let mp3Files = contents.filter { $0.hasSuffix(".mp3") }

        for fileName in mp3Files {
            let filePath = (testFilesDir as NSString).appendingPathComponent(fileName)
            let url = URL(fileURLWithPath: filePath)

            let mp3File = try Mp3File(location: url)
            let tag = try Tag(mp3File: mp3File)

            print("\(fileName):")
            print("  BPM: \(tag.bpm ?? -1)")
            print("  Star Rating: \(tag.starRating ?? -1) (byte: \(tag.rating ?? 0))")

            XCTAssertEqual(tag.bpm, 120, "BPM should be 120 for \(fileName)")
            XCTAssertEqual(tag.starRating, 4, "Star rating should be 4 for \(fileName)")
        }
    }
}
