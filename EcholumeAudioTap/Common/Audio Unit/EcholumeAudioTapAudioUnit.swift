//
//  EcholumeAudioTapAudioUnit.swift
//  EcholumeAudioTap
//
//  Created by Jarl Lyng on 31/05/2026.
//

import AVFoundation

public class EcholumeAudioTapAudioUnit: AUAudioUnit, @unchecked Sendable {
	// C++ Objects
	var kernel = EcholumeAudioTapDSPKernel()
    var processHelper: AUProcessHelper?
    var inputBus = BufferedInputBus()

    /// Sends the kernel's analysis to Echolume over loopback OSC from a ~60 Hz
    /// timer, keeping syscalls off the realtime render thread (#51).
    private var oscSender: PluginOSCSender?

	private var outputBus: AUAudioUnitBus?
    private var _inputBusses: AUAudioUnitBusArray!
    private var _outputBusses: AUAudioUnitBusArray!

	@objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        try super.init(componentDescription: componentDescription, options: options)
        outputBus = try AUAudioUnitBus(format: format)
        outputBus?.maximumChannelCount = 2

        // Create the input and output busses.
        inputBus.initialize(format, 8)

        // Create the input and output bus arrays.
        _inputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [inputBus.bus!])

        // Create the input and output bus arrays.
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus!])

        processHelper = AUProcessHelper(&kernel, &inputBus)
	}

    public override var inputBusses: AUAudioUnitBusArray {
        return _inputBusses
    }

    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusses
    }

	public override var channelCapabilities: [NSNumber] {
		get {
			return [NSNumber(value: 2), NSNumber(value: 2)]
		}
	}

    public override var  maximumFramesToRender: AUAudioFrameCount {
        get {
            return kernel.maximumFramesToRender()
        }

        set {
            kernel.setMaximumFramesToRender(newValue)
        }
    }

    public override var  shouldBypassEffect: Bool {
        get {
            return kernel.isBypassed()
        }

        set {
            kernel.setBypass(newValue)
        }
    }

    // MARK: - MIDI
    public override var audioUnitMIDIProtocol: MIDIProtocolID {
        return kernel.AudioUnitMIDIProtocol()
    }

    // MARK: - Rendering
    public override var internalRenderBlock: AUInternalRenderBlock {
        return processHelper!.internalRenderBlock()
    }

    // Allocate resources required to render.
    // Subclassers should call the superclass implementation.
    public override func allocateRenderResources() throws {
        let inputChannelCount = self.inputBusses[0].format.channelCount
        let outputChannelCount = self.outputBusses[0].format.channelCount

        if outputChannelCount != inputChannelCount {
            setRenderResourcesAllocated(false)
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization), userInfo: nil)
        }

        inputBus.allocateRenderResources(self.maximumFramesToRender)

        kernel.setMIDIOutputEventBlock(self.midiOutputEventListBlock)
        kernel.setMusicalContextBlock(self.musicalContextBlock)
        kernel.initialize(Int32(inputChannelCount), Int32(outputChannelCount), outputBus!.format.sampleRate)
        processHelper?.setChannelCount(UInt32(inputChannelCount), UInt32(outputChannelCount))

        // Start the off-render-thread OSC forwarder (#51). The closures read
        // the kernel's latest analysis floats / tap samples; the sender does
        // the FFT and network I/O on its own utility queue.
        let sender = PluginOSCSender(
            readValues: { [weak self] in
                guard let self else { return (0, 0, 0, 0, 0) }
                return (self.kernel.outLevel(), self.kernel.outLow(), self.kernel.outMid(), self.kernel.outHigh(), self.kernel.outBPM())
            },
            fillTapWindow: { [weak self] dest, count in
                self?.kernel.copyTapWindow(dest, UInt32(count))
            }
        )
        sender.start()
        oscSender = sender

        try super.allocateRenderResources()
	}

    // Deallocate resources allocated in allocateRenderResourcesAndReturnError:
    // Subclassers should call the superclass implementation.
    public override func deallocateRenderResources() {
        // Deallocate your resources.
        oscSender?.stop()
        oscSender = nil
        kernel.deInitialize()

        super.deallocateRenderResources()
    }

	public func setupParameterTree(_ parameterTree: AUParameterTree) {
		self.parameterTree = parameterTree

		// Set the Parameter default values before setting up the parameter callbacks
		for param in parameterTree.allParameters {
            kernel.setParameter(param.address, param.value)
		}

		setupParameterCallbacks()
	}

	private func setupParameterCallbacks() {
		// implementorValueObserver is called when a parameter changes value.
		parameterTree?.implementorValueObserver = { [weak self] param, value in
            self?.kernel.setParameter(param.address, value)
		}

		// implementorValueProvider is called when the value needs to be refreshed.
		parameterTree?.implementorValueProvider = { [weak self] param in
            return self!.kernel.getParameter(param.address)
		}

		// A function to provide string representations of parameter values.
		parameterTree?.implementorStringFromValueCallback = { _, valuePtr in
			guard let value = valuePtr?.pointee else {
				return "-"
			}
			return NSString.localizedStringWithFormat("%.f", value) as String
		}
	}
}
