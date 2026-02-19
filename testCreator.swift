//
//  testCreator.swift
//  REMic
//
//  Created by Novin dokht Elmi on 11/02/26.
//



import SwiftUI
import UIKit
import ImagePlayground


struct TestCreator: View {
    @State var generatedImages: [CGImage]?
    @State var isGenerationStarted: Bool = false
    @State var prompt: String = """
Once upon a time, in a vibrant jungle filled with colorful parrots and playful monkeys, there lived a curious little creature. The creature had an insatiable curiosity about the world around him. One sunny afternoon, as he wandered deeper into the jungle, he stumbled upon a peculiar sight—a very big, very friendly gorilla
        
"""
    
    var body: some View {
        VStack(alignment: .center) {
            if let image = generatedImages {
                VStack(){
                    ForEach(image, id: \.self){ selectedImage in
                        Image(uiImage: UIImage(cgImage: selectedImage))
                            .resizable()
                            .frame(width: 200, height: 200)
                    }
                }
            } else if isGenerationStarted {
                ProgressView()
            }
            else {
                ContentUnavailableView {
                    Label("Start creating beautiful images", systemImage: "apple.intelligence")
                } actions: {
                    Button("Generate"){
                        isGenerationStarted.toggle()
                        Task {
                            try await generateImage()
                        }
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .padding()
                }
            }
        }
    }
    
    func generateImage() async throws {
        do {
            let imageCreator = try await ImageCreator()
            let generationStyle = ImagePlaygroundStyle.animation
            
            
            let images = imageCreator.images(
                for: [.text("\(prompt)")],
                style: generationStyle,
                limit: 3)
            
            for try await image in images {
                if let generatedImages = generatedImages {
                    self.generatedImages = generatedImages + [image.cgImage]
                }
                else {
                    self.generatedImages = [image.cgImage]
                }
            }

        }
        catch ImageCreator.Error.notSupported {
            print("Image creation not supported on the current device.")
        }
    }
}
