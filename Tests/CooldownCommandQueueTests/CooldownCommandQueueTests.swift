import XCTest
@testable import CooldownCommandQueueCore

import NetworkHandler

class CommandQueueTests: XCTestCase {
	func testCommandQueue() {
		let url = URL(string: "http://localhost:8000")!
		let request = url.request

		let commandQueue = CooldownCommandQueue()
		let expecter = expectation(description: "Finished net mock")

		var timeTotal: Double = 0


		let iterations = 10000
		for i in 0..<iterations {
//			var thisTime = TimeInterval.random(in: 0.00...0.01)
			let thisTime: TimeInterval = 0.001
			var mockSuccess = NetworkMockingSession { (request) -> (Data?, Int, Error?) in
				let someInfo: [String: Any] = [
					"cooldown": thisTime,
					"title": "misty room",
					"description": "everywhere you look, fog",
					"id": i
				]
				let data = try! JSONSerialization.data(withJSONObject: someInfo, options: [])
				return (data, 200, nil)
			}
			mockSuccess.mockDelay = 0
			timeTotal += (i != iterations - 1) ? thisTime : 0

			let task = CooldownCommandOperation { cooldownCompletion in
				NetworkHandler.default.transferMahDatas(with: request, session: mockSuccess) { result in
					let data = try! result.get()
					let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

					let cooldown = json["cooldown"] as! TimeInterval
					let id = json["id"] as! Int

					if id.isMultiple(of: 15) {
						print(id)
					}

					cooldownCompletion(cooldown, true)
					if id == iterations - 1 {
						expecter.fulfill()
					}
				}
			}
			commandQueue.addTask(task)
		}
		let startTime = Date()

		print("Should take at least \(timeTotal) seconds")


		waitForExpectations(timeout: timeTotal * 1.5) { (error) in
			if let error = error {
				XCTFail("Timed out waiting for an expectation: \(error)")
			}
		}

		XCTAssertGreaterThanOrEqual(Date(), startTime.addingTimeInterval(timeTotal))
	}
}
