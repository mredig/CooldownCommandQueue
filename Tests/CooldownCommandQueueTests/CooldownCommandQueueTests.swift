import XCTest
@testable import CooldownCommandQueueCore

import NetworkHandler

class CommandQueueTests: XCTestCase {
	func testLongQueue() {
		let url = URL(string: "http://localhost:8000")!
		let request = url.request

		let commandQueue = CooldownCommandQueue()
		let expecter = expectation(description: "Finished net mock")

		var timeTotal: Double = 0


		let iterations = 1000
		var iteration = 0
		for i in 0..<iterations {
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
					guard iteration == id else { XCTFail("Queue happened out of order"); return }
					iteration += 1

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

	func testCommandQueue() {
		let commandQueue = CooldownCommandQueue()

		let expecter = expectation(description: "Finished net mock")

		var complete1 = false
		var complete2 = false
		let cooldown = TimeInterval(1)
		var op1Completion: Date?

		let operation = CooldownCommandOperation { cooldownCompletion in
			complete1 = true
			cooldownCompletion(cooldown, true)
			op1Completion = Date()
		}

		let operation2 = CooldownCommandOperation { cooldownCompletion in
			XCTAssertEqual(complete1, true)
			XCTAssertEqual(complete2, false)
			guard let op1completion = op1Completion else {
				XCTFail("Did not complete first operation before second")
				return
			}
			XCTAssertGreaterThanOrEqual(Date().timeIntervalSince1970, op1completion.timeIntervalSince1970 + cooldown)
			complete2 = true
			cooldownCompletion(0, true)
			expecter.fulfill()
		}

		commandQueue.addTask(operation)
		commandQueue.addTask(operation2)

		waitForExpectations(timeout: 1.11) { (error) in
			if let error = error {
				XCTFail("Timed out waiting for an expectation: \(error)")
			}
		}
	}

	func testCommandQueueError() {
		let errorExpecter = expectation(description: "Finished error")

		var errorCleanupSuccess = false

		let commandQueue = CooldownCommandQueue {
			print("Successful error cleanup completion.")
			errorCleanupSuccess = true
			errorExpecter.fulfill()
		}

		var complete1 = false
		var complete2 = false
		let cooldown = TimeInterval(1)
		var op1Completion: Date?

		let operation = CooldownCommandOperation { cooldownCompletion in
			complete1 = true
			cooldownCompletion(cooldown, false)
			op1Completion = Date()
		}

		let operation2 = CooldownCommandOperation { cooldownCompletion in
			XCTFail("op2 should not have run!")
			XCTAssertEqual(complete1, true)
			XCTAssertEqual(complete2, false)
			guard let op1completion = op1Completion else {
				XCTFail("Did not complete first operation before second")
				return
			}
			XCTAssertGreaterThanOrEqual(Date().timeIntervalSince1970, op1completion.timeIntervalSince1970 + cooldown)
			complete2 = true
			cooldownCompletion(0, true)
		}

		commandQueue.addTask(operation)
		commandQueue.addTask(operation2)

		waitForExpectations(timeout: 1.11) { (error) in
			if let error = error {
				XCTFail("Timed out waiting for an expectation: \(error)")
			}
		}
		XCTAssertEqual(errorCleanupSuccess, true)

		let continuationExpecter = expectation(description: "Finished error")
		let op3 = CooldownCommandOperation { cooldownCompletion in
			print("Queue continued afterward just fine.")
			cooldownCompletion(0.01, true)
			continuationExpecter.fulfill()
		}

		commandQueue.addTask(op3)
		waitForExpectations(timeout: 1.11) { (error) in
			if let error = error {
				XCTFail("Timed out waiting for an expectation: \(error)")
			}
		}
	}

	func testDelayedAdd() {
		// add to queu for 2 second cooldown
		// add another to queue 1 second later
		// confirm second add does not run until it's time
		let commandQueue = CooldownCommandQueue()

		let cooldownDuration: TimeInterval = 2
		let cooldownCompletionTime = Date(timeIntervalSinceNow: cooldownDuration)
		let expector = expectation(description: "Delayed add")

		let task = CooldownCommandOperation { cooldownCompletion in
			cooldownCompletion(cooldownDuration, true)
		}
		commandQueue.addTask(task)

		sleep(1)
		let task2 = CooldownCommandOperation { cooldownCompletion in
			let now = Date()
			XCTAssertGreaterThanOrEqual(now.timeIntervalSince1970, cooldownCompletionTime.timeIntervalSince1970)
			let difference = now.timeIntervalSince1970 - cooldownCompletionTime.timeIntervalSince1970
			print("task2 started \(difference) seconds after cooldown completed")
			cooldownCompletion(0, true)
			expector.fulfill()
		}
		commandQueue.addTask(task2)

		wait(for: [expector], timeout: 3)
	}

	func testJumpQueue() {
		// add items A and B to queue
		// add item C to jump the queue before B, while A is on cooldown
		// confirm order runs in ACB

		let commandQueue = CooldownCommandQueue()

		let cooldownDuration: TimeInterval = 0.5
		let expector = expectation(description: "wait for completion")

		var taskADone = false
		var taskBDone = false
		var taskCDone = false

		let taskA = CooldownCommandOperation { cooldownCompletion in
			XCTAssertEqual(taskADone, false)
			XCTAssertEqual(taskBDone, false)
			XCTAssertEqual(taskCDone, false)
			taskADone = true
			print("A done")
			cooldownCompletion(cooldownDuration, true)
		}

		let taskB = CooldownCommandOperation { cooldownCompletion in
			XCTAssertEqual(taskADone, true)
			XCTAssertEqual(taskBDone, false)
			XCTAssertEqual(taskCDone, true)
			taskBDone = true
			print("B done")
			cooldownCompletion(cooldownDuration, true)
			expector.fulfill()
		}

		let taskC = CooldownCommandOperation { cooldownCompletion in
			XCTAssertEqual(taskADone, true)
			XCTAssertEqual(taskBDone, false)
			XCTAssertEqual(taskCDone, false)
			taskCDone = true
			print("C done")
			cooldownCompletion(cooldownDuration, true)
		}

		commandQueue.addTask(taskA)
		commandQueue.addTask(taskB)
		commandQueue.jumpTask(taskC)

		wait(for: [expector], timeout: 3)

		XCTAssertEqual(taskADone, true)
		XCTAssertEqual(taskBDone, true)
		XCTAssertEqual(taskCDone, true)
	}
}
