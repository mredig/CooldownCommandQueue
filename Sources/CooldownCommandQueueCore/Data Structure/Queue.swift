//
//  Queue.swift
//  App
//
//  Created by Michael Redig on 2/11/20.
//

import Foundation

public class Queue<T> {
	private var storage = LinkedList<T>()

	var count: Int { storage.count }

	public func enqueue(_ value: T) {
		storage.addToHead(value: value)
	}

	public func dequeue() -> T? {
		storage.removeFromTail()
	}

	public func jumpQueue(_ value: T) {
		storage.addToTail(value: value)
	}
}
