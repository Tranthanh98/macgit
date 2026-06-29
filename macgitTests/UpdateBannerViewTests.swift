//
//  macgit (Commit+) - a macOS Git client built with Swift and SwiftUI.
//  Copyright (C) 2026  Thanh Tran <trantienthanh2412@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
import XCTest
@testable import macgit

@MainActor
final class UpdateBannerViewTests: XCTestCase {
    func testIdleStateHasNoBannerModel() {
        XCTAssertNil(UpdateBannerView.Model.make(for: .idle))
    }

    func testCheckingStateHasNoBannerModel() {
        XCTAssertNil(UpdateBannerView.Model.make(for: .checking))
    }

    func testAvailableStateShowsUpdateTitle() {
        let model = UpdateBannerView.Model.make(for: .available)

        XCTAssertEqual(model?.title, "Update")
        XCTAssertEqual(model?.isEnabled, true)
    }

    func testDownloadingStateShowsDisabledDownloadingTitle() {
        let model = UpdateBannerView.Model.make(for: .downloading)

        XCTAssertEqual(model?.title, "Downloading…")
        XCTAssertEqual(model?.isEnabled, false)
    }
}
