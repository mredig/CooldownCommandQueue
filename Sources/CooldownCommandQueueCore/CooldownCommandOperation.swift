//
//  File.swift
//  
//
//  Created by Michael Redig on 3/5/20.
//

import Foundation

public class CooldownCommandOperation: CommandOperation {
	public var cooldown: TimeInterval?

	public typealias CooldownCompletion = (TimeInterval) -> Void
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
		let cooldownTaskFinish = { (time: TimeInterval) in
			self.cooldown = time
			self.state = .isFinished
		}
		state = .isExecuting
		cooldownTask(cooldownTaskFinish)
	}

}
