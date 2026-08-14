import XCTest

final class BusinessFlowMacUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMacCanOpenBusinessOverview() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()

        let businessEntry = app.staticTexts["经营总览"].firstMatch
        XCTAssertTrue(businessEntry.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["客户订单"].firstMatch.waitForExistence(timeout: 5))
        businessEntry.tap()

        XCTAssertTrue(app.windows["经营总览"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["真实收付款"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["统计口径"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["导出报表"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Mac V0.4 真实收付款"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMacCanOpenServiceOrders() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()

        let ordersEntry = app.staticTexts["客户订单"].firstMatch
        XCTAssertTrue(ordersEntry.waitForExistence(timeout: 5))
        ordersEntry.tap()

        XCTAssertTrue(app.windows["客户订单"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["新建客户订单"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Mac V0.8 客户订单"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMacCanOpenProductEditorAndAudioSelfTest() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()

        app.staticTexts["产品与服务"].firstMatch.tap()
        XCTAssertTrue(app.buttons["新建产品"].waitForExistence(timeout: 5))
        app.buttons["新建产品"].tap()
        XCTAssertTrue(app.staticTexts["产品定义"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()

        app.staticTexts["安全中心"].firstMatch.tap()
        let audioButton = app.buttons["开始 10 秒录音测试"]
        if !audioButton.waitForExistence(timeout: 2) {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(audioButton.waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Mac V0.8 产品与录音自检"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMacCanOpenPackageChangeTimeline() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing-v06")
        app.launch()

        let ordersEntry = app.staticTexts["客户订单"].firstMatch
        XCTAssertTrue(ordersEntry.waitForExistence(timeout: 5))
        ordersEntry.tap()

        let testOrder = app.buttons.matching(NSPredicate(format: "label CONTAINS 'C-UI-V06'")).firstMatch
        XCTAssertTrue(testOrder.waitForExistence(timeout: 5))
        testOrder.tap()

        XCTAssertTrue(app.staticTexts["订单变更记录"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["记录一项人工变更"].waitForExistence(timeout: 5))
        app.buttons["记录一项人工变更"].tap()
        XCTAssertTrue(app.staticTexts["记录订单变更"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["保存记录"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Mac V0.6 订单变更记录"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMacCanOpenConsultationArchiveWorkflow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing-v07")
        app.launch()

        let recordsEntry = app.staticTexts["咨询资料"].firstMatch
        XCTAssertTrue(recordsEntry.waitForExistence(timeout: 5))
        recordsEntry.tap()

        let testRecord = app.buttons.matching(NSPredicate(format: "label CONTAINS 'C-UI-V07'")).firstMatch
        XCTAssertTrue(testRecord.waitForExistence(timeout: 5))
        testRecord.tap()

        XCTAssertTrue(app.staticTexts["本次咨询"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["客户确认核对"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["永久资料文件"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["导入录音、牌阵照片或转写文件"].waitForExistence(timeout: 5))
        let recordScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(recordScrollView.waitForExistence(timeout: 5))
        recordScrollView.swipeUp()
        XCTAssertTrue(app.buttons["从照片中选择牌阵照片"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Mac V0.7 咨询归档工作区"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
