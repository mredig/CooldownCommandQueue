//
//  Stack.swift
//  BSVBattleRoyale
//
//  Created by Michael Redig on 2/4/20.
//  Copyright © 2020 joshua kaunert. All rights reserved.
//

import Foundation

class Stack<T> {

	let storage = LinkedList<T>()

	var count: Int {
		storage.count
	}

	func push(_ item: T) {
		storage.addToHead(value: item)
	}

	@discardableResult func pop() -> T? {
		storage.removeFromHead()
	}

	func peek() -> T? {
		storage.head?.wrappedValue
	}
}
