//
//  MetalView.swift
//  echolume
//

import MetalKit
import SwiftUI

struct MetalView: NSViewRepresentable {
    var visualParamsProvider: VisualParamsProvider
    /// Called on the main thread when Metal device or renderer init fails.
    /// Pass a non-nil string to set the error; pass nil to clear it.
    var onError: ((String?) -> Void)?

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        let device = MTLCreateSystemDefaultDevice()
        mtkView.device = device
        mtkView.delegate = context.coordinator
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false

        if device == nil {
            let msg = "This Mac does not support Metal. Echolume cannot render visuals."
            Log.error("[Renderer] \(msg)")
            DispatchQueue.main.async { onError?(msg) }
        }
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.paramsProvider = visualParamsProvider
        context.coordinator.onError = onError
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(visualParamsProvider: visualParamsProvider, onError: onError)
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var paramsProvider: VisualParamsProvider
        var onError: ((String?) -> Void)?
        var renderer: Renderer?
        private var didReportInitFailure = false

        init(visualParamsProvider: VisualParamsProvider, onError: ((String?) -> Void)?) {
            self.paramsProvider = visualParamsProvider
            self.onError = onError
            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.mtkView(view, drawableSizeWillChange: size)
        }

        func draw(in view: MTKView) {
            if renderer == nil, let device = view.device {
                renderer = Renderer(metalDevice: device, paramsProvider: paramsProvider)
                if renderer == nil && !didReportInitFailure {
                    didReportInitFailure = true
                    let msg = "Renderer failed to initialize. Try restarting the app or check Console for details."
                    Log.error("[Renderer] \(msg)")
                    let cb = onError
                    DispatchQueue.main.async { cb?(msg) }
                }
            }
            renderer?.draw(in: view)
        }
    }
}
