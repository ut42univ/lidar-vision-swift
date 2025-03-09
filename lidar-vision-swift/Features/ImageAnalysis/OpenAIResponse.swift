//
//  OpenAIResponse.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/03/09.
//


import Foundation

struct OpenAIResponse: Decodable {
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: Message
    }
    
    struct Message: Decodable {
        let content: String
    }
}
