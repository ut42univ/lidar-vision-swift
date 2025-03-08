//
//  EnvironmentManager.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/03/08.
//


import Foundation

struct EnvironmentManager {
    static var openAIAPIKey: String {
        guard let apiKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            fatalError("OpenAI API Key is not set. Please add 'OPENAI_API_KEY' to Info.plist.")
        }
        return apiKey
    }
}