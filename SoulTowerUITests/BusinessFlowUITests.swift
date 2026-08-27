import XCTest

final class BusinessFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPhoneCanOpenBusinessOverviewFromMore() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()

        let moreTab = app.tabBars.buttons["更多"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 5))
        moreTab.tap()

        let businessEntry = app.staticTexts["经营总览"].firstMatch
        XCTAssertTrue(businessEntry.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["客户订单"].firstMatch.waitForExistence(timeout: 5))
        businessEntry.tap()

        XCTAssertTrue(app.navigationBars["经营总览"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["真实收付款"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["统计口径"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["导出报表"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "iPhone V0.4 真实收付款"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhoneCanOpenServiceOrdersFromMore() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["更多"].waitForExistence(timeout: 5))
        app.tabBars.buttons["更多"].tap()

        let ordersEntry = app.staticTexts["客户订单"].firstMatch
        XCTAssertTrue(ordersEntry.waitForExistence(timeout: 5))
        ordersEntry.tap()

        XCTAssertTrue(app.navigationBars["客户订单"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["新建客户订单"].waitForExistence(timeout: 5))
        app.buttons["新建客户订单"].tap()
        XCTAssertTrue(app.navigationBars["新建客户订单"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["客户与产品"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["建立订单时的收款（可选）"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "iPhone V0.8 新建客户订单"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhoneCanOpenPackageAfterSaleTools() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing-v06")
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["更多"].waitForExistence(timeout: 5))
        app.tabBars.buttons["更多"].tap()
        app.staticTexts["客户订单"].firstMatch.tap()

        let testOrder = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'C-UI-V06'")).firstMatch
        XCTAssertTrue(testOrder.waitForExistence(timeout: 5))
        testOrder.tap()

        XCTAssertTrue(app.staticTexts["套餐权益"].waitForExistence(timeout: 5))
        for _ in 0..<4 where !app.buttons["人工延长套餐有效期"].exists { app.swipeUp() }
        XCTAssertTrue(app.buttons["人工延长套餐有效期"].waitForExistence(timeout: 5))
        app.buttons["人工延长套餐有效期"].tap()
        XCTAssertTrue(app.navigationBars["套餐延期"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["确认延期"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "iPhone V0.6 套餐延期"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhoneCanOpenProductEditorAndAudioSelfTest() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()

        app.tabBars.buttons["更多"].tap()
        app.staticTexts["产品与服务"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["产品与服务"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["新建产品"].waitForExistence(timeout: 5))
        app.buttons["新建产品"].tap()
        XCTAssertTrue(app.navigationBars["新建产品"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["产品定义"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()

        app.navigationBars.buttons.firstMatch.tap()
        app.staticTexts["安全中心"].firstMatch.tap()
        for _ in 0..<5 where !app.buttons["开始 10 秒录音测试"].exists { app.swipeUp() }
        XCTAssertTrue(app.buttons["开始 10 秒录音测试"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "iPhone V0.8 产品与录音自检"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhonePackageCancellationRequiresReturnChoice() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing-v06")
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["排期"].waitForExistence(timeout: 5))
        app.tabBars.buttons["排期"].tap()

        let packageAppointment = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'C-UI-V06'")).firstMatch
        XCTAssertTrue(packageAppointment.waitForExistence(timeout: 5))
        packageAppointment.tap()

        for _ in 0..<5 where !app.buttons["取消预约"].exists {
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["取消预约"].waitForExistence(timeout: 5))
        app.buttons["取消预约"].tap()
        XCTAssertTrue(app.buttons["取消预约并返还 1 次"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["取消预约但不返还次数"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "iPhone V0.6 套餐取消返还选择"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhoneCanOpenConsultationArchiveWorkflow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing-v07")
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["资料"].waitForExistence(timeout: 5))
        app.tabBars.buttons["资料"].tap()

        let testRecord = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'C-UI-V07'")).firstMatch
        XCTAssertTrue(testRecord.waitForExistence(timeout: 5))
        testRecord.tap()

        XCTAssertTrue(app.staticTexts["本次咨询"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["客户确认核对"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["永久资料文件"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["导入录音、牌阵照片或转写文件"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.buttons["从照片中选择牌阵照片"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "iPhone V0.7 咨询归档工作区"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhoneCanOpenBrandGrowthFromMore() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["更多"].waitForExistence(timeout: 5))
        app.tabBars.buttons["更多"].tap()
        let brandEntry = app.staticTexts["品牌增长"].firstMatch
        XCTAssertTrue(brandEntry.waitForExistence(timeout: 5))
        brandEntry.tap()

        XCTAssertTrue(app.navigationBars["品牌增长"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["品牌增长工作台"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["新建选题"].waitForExistence(timeout: 5))
        app.buttons["新建选题"].tap()
        XCTAssertTrue(app.staticTexts["来源边界"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "iPhone 品牌增长新建选题"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhoneBrandM2CanViewDataAndWeeklyReview() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchArguments.append("--ui-testing-brand-m2")
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["更多"].waitForExistence(timeout: 5))
        app.tabBars.buttons["更多"].tap()
        let brandEntry = app.staticTexts["品牌增长"].firstMatch
        XCTAssertTrue(brandEntry.waitForExistence(timeout: 5))
        brandEntry.tap()

        let pagePicker = app.descendants(matching: .any)["brand-page-picker"]
        XCTAssertTrue(pagePicker.waitForExistence(timeout: 5))
        pagePicker.tap()
        XCTAssertTrue(app.buttons["数据中心"].waitForExistence(timeout: 5))
        app.buttons["数据中心"].tap()
        XCTAssertTrue(app.staticTexts["数据采集原则"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["新增快照"].waitForExistence(timeout: 5))

        app.descendants(matching: .any)["brand-page-picker"].tap()
        XCTAssertTrue(app.buttons["每周复盘"].waitForExistence(timeout: 5))
        app.buttons["每周复盘"].tap()
        XCTAssertTrue(app.staticTexts["每周复盘"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["brand-weekly-review-row"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "iPhone 品牌增长 M2 周复盘"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhoneBrandM3CanViewConsentAssetsAndTasks() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchArguments.append("--ui-testing-brand-m3")
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["更多"].waitForExistence(timeout: 5))
        app.tabBars.buttons["更多"].tap()
        app.staticTexts["品牌增长"].firstMatch.tap()

        let pagePicker = app.descendants(matching: .any)["brand-page-picker"]
        XCTAssertTrue(pagePicker.waitForExistence(timeout: 5))
        pagePicker.tap()
        XCTAssertTrue(app.buttons["素材授权"].waitForExistence(timeout: 5))
        app.buttons["素材授权"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["brand-m3-consent-list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["brand-m3-asset-list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["brand-m3-task-list"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "iPhone 品牌增长 M3 素材授权"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhoneBrandM4ShowsVerifiedAutomationBoundariesAndExperiments() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchArguments.append("--ui-testing-brand-m4")
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["更多"].waitForExistence(timeout: 5))
        app.tabBars.buttons["更多"].tap()
        app.staticTexts["品牌增长"].firstMatch.tap()

        let pagePicker = app.descendants(matching: .any)["brand-page-picker"]
        XCTAssertTrue(pagePicker.waitForExistence(timeout: 5))
        pagePicker.tap()
        XCTAssertTrue(app.buttons["平台自动化"].waitForExistence(timeout: 5))
        app.buttons["平台自动化"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["brand-m4-boundary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["brand-m4-connections"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["个人微信朋友圈"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["M4 测试：标题方向对比"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "iPhone 品牌增长 M4 平台自动化"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
