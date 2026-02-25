//
//  MetalView.swift
//  echolume
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    var visualParamsProvider: VisualParamsProvider

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.paramsProvider = visualParamsProvider
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(visualParamsProvider: visualParamsProvider)
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var paramsProvider: VisualParamsProvider
        var renderer: Renderer?

        init(visualParamsProvider: VisualParamsProvider) {
            self.paramsProvider = visualParamsProvider
            super.init()
            if let device = MTLCreateSystemDefaultDevice() {
                renderer = Renderer(metalDevice: device, paramsProvider: visualParamsProvider)
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.mtkView(view, drawableSizeWillChange: size)
        }

        func draw(in view: MTKView) {
            renderer?.draw(in: view)
        }
    }
}
