//
//  PhotoDetailView.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/03/08.
//


import SwiftUI

struct PhotoDetailView: View {
    let image: UIImage
    @StateObject private var openAIManager = OpenAIManager(apiKey: EnvironmentManager.openAIAPIKey)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    if openAIManager.isLoading {
                        ProgressView("Analyzing image...")
                            .padding()
                    } else if let error = openAIManager.error {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                                .padding(.bottom, 4)
                            
                            Text("An error occurred")
                                .font(.headline)
                            
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Retry") {
                                openAIManager.analyzeImage(image)
                            }
                            .padding(.top, 8)
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else if !openAIManager.imageDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Image Description")
                                .font(.headline)
                                .padding(.leading, 8)
                            
                            Text(openAIManager.imageDescription)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                if openAIManager.imageDescription.isEmpty && openAIManager.error == nil && !openAIManager.isLoading {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Analyze Image with AI") {
                            openAIManager.analyzeImage(image)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
        }
        .onAppear {
            // Uncomment to perform automatic analysis
            // openAIManager.analyzeImage(image)
        }
    }
}