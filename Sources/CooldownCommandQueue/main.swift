//
//  File 2.swift
//  
//
//  Created by Michael Redig on 3/5/20.
//

import Foundation
import CooldownCommandQueueCore


let apiKey = "a010c017b8562e13b8f933b546a71caccca1c990"

let baseURL = URL(string: "http://localhost:8000/api/adv/init")!

var request = URLRequest(url: baseURL)
request.httpMethod = "GET"
request.addValue("application/json", forHTTPHeaderField: "Content-Type")
request.addValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

let cooldownCommandQueue = CooldownCommandQueue()

for i in 0...10 {
	let task = CooldownCommandOperation { cooldownTask in
		URLSession.shared.dataTask(with: request) { (data, _, error) in
			if let error = error {
				print("error: \(error)")
				return
			}

			let json = try! JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any]

			let cooldown = json["cooldown"]! as! TimeInterval
			let title = json["title"] as? String
			let messages = json["messages"] as? [String]
			print("cooldown: \(cooldown)")
			print("title: \(title)")
			print("messages: \(messages)")
			print(i, Date())
			cooldownTask(cooldown)
		}.resume()
	}
	cooldownCommandQueue.addTask(task)
}

while true {
	sleep(1)
}
