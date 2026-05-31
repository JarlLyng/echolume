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
        let mtkView = PausableMTKView()
        let device = MTLCreateSystemDefaultDevice()
        mtkView.device = device
        mtkView.delegate = context.coordinator
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.enableSetNeedsDisplay = false
        // preferredFramesPerSecond + isPaused are managed by PausableMTKView
        // once the view is attached to a window (honors the display's refresh
        // rate and pauses while the window is fully occluded).

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

/// MTKView that honors the display's refresh rate and pauses its render loop
/// whenever its window is fully occluded/hidden — avoids burning GPU/power on a
/// 60 fps (or 120 fps ProMotion) feedback pass that nobody can see (e.g. the
/// Setup window while Live runs fullscreen on an external display).
final class PausableMTKView: MTKView {
    private var occlusionObserver: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let obs = occlusionObserver {
            NotificationCenter.default.removeObserver(obs)
            occlusionObserver = nil
        }

        guard let window = window else {
            isPaused = true
            return
        }

        // Match the display's actual refresh rate (e.g. 120 Hz ProMotion).
        preferredFramesPerSecond = max(30, window.screen?.maximumFramesPerSecond ?? 60)
        updatePause(for: window)

        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self, let window = self.window else { return }
            self.updatePause(for: window)
        }
    }

    private func updatePause(for window: NSWindow) {
        isPaused = !window.occlusionState.contains(.visible)
    }

    deinit {
        if let obs = occlusionObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
