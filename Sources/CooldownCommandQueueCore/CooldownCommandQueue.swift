import Foundation


public class CooldownCommandQueue {

	private var internalQueue = DispatchQueue(label: "com.redeggproductions.InternalCooldownQueue")

	private var _queuedItems = Queue<CooldownCommandOperation>()
	private(set) var queuedItems: Queue<CooldownCommandOperation> {
		get { internalQueue.sync { _queuedItems } }
		set { internalQueue.sync { _queuedItems = newValue } }
	}
	private var _cooldown: Date?
	private(set) var cooldown: Date? {
		get { internalQueue.sync { _cooldown } }
		set { internalQueue.sync { _cooldown = newValue } }
	}

	private var _currentItem: CooldownCommandOperation?
	private(set) var currentItem: CooldownCommandOperation? {
		get { internalQueue.sync { _currentItem } }
		set { internalQueue.sync { _currentItem = newValue } }
	}

	private let _operationQueue: OperationQueue = {
		let op = OperationQueue()
		op.maxConcurrentOperationCount = 1
		return op
	}()
	private var operationQueue: OperationQueue {
		internalQueue.sync { _operationQueue }
	}

	let errorCleanupTask: (() -> Void)?

	/// In the event of a failed task, the queue will be cleared and the cleanup task will run. The cleanup task is optional and can be anything you wish to pass in.
	public init(errorCleanupTask: (() -> Void)? = nil) {
		self.errorCleanupTask = errorCleanupTask
	}

	public func addTask(_ task: CooldownCommandOperation) {
		queuedItems.enqueue(task)
		start()
	}

	private func errorReset() {
		print("Errored - resetting CooldownCommandQueue.")
		while queuedItems.count > 0 {
			_ = queuedItems.dequeue()
		}
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
			let cooldownWait = BlockOperation { [weak self] in
				// this runs after the task finishes and the completion block runs
				guard let self = self else { return }
				let cooldownDate = self.cooldown ?? Date()
				while Date() < cooldownDate {
					usleep(10000)
				}
				self.currentItem = nil
				self.start()
			}
			self.operationQueue.addOperation(cooldownWait)
		}
		operationQueue.addOperation(task)
		operationQueue.addOperation(completionBlock)
	}
}
