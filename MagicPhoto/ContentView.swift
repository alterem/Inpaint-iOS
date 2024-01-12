//
//  ContentView.swift
//  MagicPhoto
//
//  Created by wu miao on 2024/1/11.
//

import SwiftUI
import RealityKit
import RealityKitContent
import PhotosUI

class MagicPhotoViewModel: ObservableObject {
    var modleGen = DepthImage3DModleGenerator()
    var deepPrediction = MiDaSImageDepthPrediction()
    
    @Published var modelData: MagicModelData? = nil
    @Published var model: ModelEntity?
    
    func process(_ image: UIImage) {
        deepPrediction.depthPrediction(image: image) { resultImage, depthData, err in
            if let depthData {
                let result = self.modleGen.process(depthData: depthData)
                self.modelData = result
                if let result {
                    var descr = MeshDescriptor(name: "tritri")
                    var maxZ = 0.0;
                    descr.positions = MeshBuffers.Positions(result.vertexList.map({ vec in
                        maxZ = max(maxZ, Double(vec.z))
                        return SIMD3<Float>.init(x: vec.x / 5.0, y: vec.y / 5.0, z: vec.z / 5.0)
                    }))
                    print(maxZ)
                    descr.primitives = .triangles(result.indices)
                    descr.textureCoordinates = MeshBuffer.init(result.texCoordList.map({ point in
                        return SIMD2<Float>.init(x: point.x, y: point.y)
                    }))
                    
                    let textRes = try! TextureResource.generate(from: image.cgImage!, options: .init(semantic: .color))
                    
                    var triMat = UnlitMaterial(color: .clear)
                    triMat.color = .init(texture: .init(textRes))

                    
                    let generatedModel = ModelEntity(
                       mesh: try! .generate(from: [descr]),
                       materials: [triMat]
                    )
                    
//                    generatedModel.setSunlight(intensity: 5.25)
                    
                    self.model = generatedModel
                }
            }
        }
    }
}

struct ContentView: View {

    @State var enlarge = false
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    
    @State var pickingImage = false
    
    @StateObject var vm = MagicPhotoViewModel()

    var body: some View {
        VStack {
            if !pickingImage {
                Group {
                    if let model = vm.model {
                        RealityView { content in
                            content.add(model)
                        }
                    } else {
                        RealityView { content in
                            // Add the initial RealityKit content
                            if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
                                content.add(scene)
                            }
                        } update: { content in
                            // Update the RealityKit content when SwiftUI state changes
                            if let scene = content.entities.first {
                                let uniformScale: Float = enlarge ? 1.4 : 1.0
                                scene.transform.scale = [uniformScale, uniformScale, uniformScale]
                            }
                        }
                    }
                }
                .gesture(TapGesture().targetedToAnyEntity().onEnded { _ in
                    enlarge.toggle()
                    pickingImage.toggle()
                })
                
                HStack {
                    Button {
                        pickingImage = true
                    } label: {
                        Text("Pick your photo !!!")
                    }
                    Button {
                        
                    } label: {
                        Text("Pin to wall !!!")
                    }
                }
            }
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
            }
        }
        .photosPicker(isPresented: $pickingImage,
                       selection: $selectedItem,
                       matching: .images)
        .onChange(of: selectedItem, { oldValue, newValue in
            Task {
                // Retrieve selected asset in the form of Data
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                    let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                    vm.process(uiImage)
                }
            }
        })
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
}
