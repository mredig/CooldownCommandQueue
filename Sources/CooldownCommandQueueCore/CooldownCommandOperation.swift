//
//  File.swift
//  
//
//  Created by Michael Redig on 3/5/20.
//

import Foundation

public class CooldownCommandOperation: CommandOperation {
	private(set) var cooldown: TimeInterval?
	private(set) var success: Bool?

	public typealias CooldownCompletion = (TimeInterval, Bool) -> Void
	public typealias CooldownBaseTask = (@escaping CooldownCompletion) -> Void

	let cooldownTask: CooldownBaseTask

	public override init(isAsync: Bool = true, task: @escaping () -> Void) {
		fatalError("init async/task not implmented")
	}

	/// You MUST call the cooldown completion handler or this wont work!
	public init(isAsync: Bool = false, cooldownTask: @escaping CooldownBaseTask) {
		self.cooldownTask = cooldownTask
		super.init(isAsync: isAsync, task: { } )
	}

	public override func start() {
		let cooldownTaskFinish = { (time: TimeInterval, success: Bool) in
			self.cooldown = time
			self.success = success
			self.state = .isFinished
		}
		state = .isExecuting
		cooldownTask(cooldownTaskFinish)
	}

}
