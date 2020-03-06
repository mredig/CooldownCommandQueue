//
//  ConcurrentOperation.swift
//  Astronomy
//
//  Created by Andrew R Madsen on 9/5/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

import Foundation

public class CommandOperation: Operation {

	// MARK: Types

	public enum State: String {
		case isReady, isExecuting, isFinished
	}

	// MARK: Properties
	public let task: () -> Void

	private var _state = State.isReady

	private let stateQueue = DispatchQueue(label: "com.redeggproductions.CommandOperationStateQueue")
	var state: State {
		get {
			var result: State?
			let queue = self.stateQueue
			queue.sync {
				result = _state
			}
			return result!
		}

		set {
			let oldValue = state
			willChangeValue(forKey: newValue.rawValue)
			willChangeValue(forKey: oldValue.rawValue)

			stateQueue.sync { self._state = newValue }

			didChangeValue(forKey: oldValue.rawValue)
			didChangeValue(forKey: newValue.rawValue)
		}
	}

	// MARK: NSOperation
	override dynamic public var isReady: Bool { super.isReady && state == .isReady }
	override dynamic public var isExecuting: Bool { state == .isExecuting }
	override dynamic public var isFinished: Bool { state == .isFinished }
	private var _isAsync: Bool
	override public var isAsynchronous: Bool { _isAsync }

	public init(isAsync: Bool = true, task: @escaping () -> Void) {
		self.task = task
		self._isAsync = isAsync
		super.init()
	}

	override public func start() {
		defer {
			state = .isFinished
		}
		state = .isExecuting
		task()
	}
}
