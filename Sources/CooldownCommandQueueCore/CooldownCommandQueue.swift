import Foundation


public class CooldownCommandQueue {

	private var propertyQueue = DispatchQueue(label: "com.redeggproductions.propertyQueue")
	private var executionQueue = DispatchQueue(label: "com.redeggproductions.executionQueue")

	private var _queuedItems = Queue<CooldownCommandOperation>()
	private(set) var queuedItems: Queue<CooldownCommandOperation> {
		get { propertyQueue.sync { _queuedItems } }
		set { propertyQueue.sync { _queuedItems = newValue } }
	}
	private var _cooldown: Date?
	private(set) var cooldown: Date? {
		get { propertyQueue.sync { _cooldown } }
		set { propertyQueue.sync { _cooldown = newValue } }
	}

	private var _currentItem: CooldownCommandOperation?
	public private(set) var currentItem: CooldownCommandOperation? {
		get { propertyQueue.sync { _currentItem } }
		set { propertyQueue.sync { _currentItem = newValue } }
	}

	private let _operationQueue: OperationQueue = {
		let op = OperationQueue()
		op.maxConcurrentOperationCount = 1
		return op
	}()
	private var operationQueue: OperationQueue {
		propertyQueue.sync { _operationQueue }
	}

	public var currentlyExecuting: Bool {
		queuedItems.count > 0 || currentItem != nil
	}

	public var waitingOnCooldown: Bool {
		(cooldown ?? Date(timeIntervalSinceNow: -1)) > Date()
	}

	public var cooldownTime: Date {
		cooldown ?? Date()
	}

	public var cooldownRemaining: TimeInterval {
		cooldownTime.timeIntervalSince1970 - Date().timeIntervalSince1970
	}

	let errorCleanupTask: (() -> Void)?

	/// In the event of a failed task, the queue will be cleared and the cleanup task will run. The cleanup task is optional and can be anything you wish to pass in.
	public init(errorCleanupTask: (() -> Void)? = nil) {
		self.errorCleanupTask = errorCleanupTask
	}

	/// Adds an task to the end of the queue
	public func addTask(_ task: CooldownCommandOperation) {
		queuedItems.enqueue(task)
		executionQueue.sync {
			start()
		}
	}

	// Adds a task to the front of the queue
	public func jumpTask(_ task: CooldownCommandOperation) {
		queuedItems.jumpQueue(task)
		executionQueue.sync {
			start()
		}
	}

	private func errorReset() {
		print("Errored - resetting CooldownCommandQueue.")
		while queuedItems.count > 0 {
			_ = queuedItems.dequeue()
		}
		currentItem = nil
		errorCleanupTask?()
	}

	private func start() {
		guard currentItem == nil else { return }
		if let cooldown = cooldown {
			guard Date() > cooldown else { return }
		}

		guard let task = queuedItems.dequeue() else { return }
		currentItem = task

		let completionBlock = BlockOperation { [weak self] in
			guard let self = self else { return }
			guard task.success == true else {
				self.errorReset()
				return
			}
			guard let cooldown = task.cooldown else { fatalError("Task \(task) failed somehow!") }
			self.cooldown = Date(timeIntervalSinceNow: cooldown)
			self.currentItem = nil
		}

		let cooldownWait = BlockOperation { [weak self] in
			// this runs after the task finishes and the completion block runs
			guard let self = self else { return }
			let cooldownDate = self.cooldown ?? Date()
			while Date() < cooldownDate {
				usleep(100)
			}
			self.executionQueue.sync {
				self.start()
			}
		}

		guard task.isReady else { return }
		guard completionBlock.isReady else { return }
		guard cooldownWait.isReady else { return }
		completionBlock.addDependency(task)
		cooldownWait.addDependency(completionBlock)
		operationQueue.addOperation(task)
		operationQueue.addOperation(completionBlock)
		operationQueue.addOperation(cooldownWait)

		weak var wTask = task
		weak var wCompletionBlock = completionBlock
		weak var wCooldownWait = cooldownWait
		
		DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
			print("Zombie ops delayed:", wTask, wCompletionBlock, wCooldownWait)
		}
	}
}
