//
//  CrashReportingTests.swift
//  echolumeTests
//

import Foundation
import Testing
@testable import echolume

struct CrashReportingTests {

    @Test func redactUserPaths_replacesTheAccountName() {
        #expect(
            CrashReporting.redactUserPaths("/Users/jarl.l/Downloads/echolume.app/Contents/MacOS/echolume")
                == "/Users/<redacted>/Downloads/echolume.app/Contents/MacOS/echolume"
        )
    }

    @Test func redactUserPaths_keepsTheRestOfThePath() {
        #expect(
            CrashReporting.redactUserPaths("/Users/someone/Library/Developer/Xcode/DerivedData/x/echolume")
                == "/Users/<redacted>/Library/Developer/Xcode/DerivedData/x/echolume"
        )
    }

    @Test func redactUserPaths_redactsEveryOccurrence() {
        #expect(
            CrashReporting.redactUserPaths("/Users/a/one and /Users/b/two")
                == "/Users/<redacted>/one and /Users/<redacted>/two"
        )
    }

    @Test func redactUserPaths_leavesNonHomePathsAlone() {
        #expect(
            CrashReporting.redactUserPaths("/Applications/echolume.app/Contents/MacOS/echolume")
                == "/Applications/echolume.app/Contents/MacOS/echolume"
        )
        #expect(CrashReporting.redactUserPaths("echolume") == "echolume")
        #expect(CrashReporting.redactUserPaths("") == "")
    }
}
