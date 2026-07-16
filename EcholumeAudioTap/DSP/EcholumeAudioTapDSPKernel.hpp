//
//  EcholumeAudioTapDSPKernel.hpp
//  EcholumeAudioTap
//
//  Created by Jarl Lyng on 31/05/2026.
//

#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <CoreMIDI/CoreMIDI.h>
#import <algorithm>
#import <vector>
#import <span>
#import <cmath>
#import <cstring>

#import "EcholumeAudioTapParameterAddresses.h"
#import "EcholumeAudioTapBufferedAudioBus.hpp"

/*
 EcholumeAudioTapDSPKernel
 As a non-ObjC class, this is safe to use from render thread.
 */
class EcholumeAudioTapDSPKernel {
public:
    void initialize(int inputChannelCount, int outputChannelCount, double inSampleRate) {
        mSampleRate = inSampleRate;
    }

    void deInitialize() {
    }


    // MARK: - Bypass
    bool isBypassed() {
        return mBypassed;
    }
    
    void setBypass(bool shouldBypass) {
        mBypassed = shouldBypass;
    }
    
    // MARK: - Parameter Getter / Setter
    // Add a case for each parameter in EcholumeAudioTapParameterAddresses.h
    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case EcholumeAudioTapParameterAddress::gain:
                mGain = value;
                break;
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        // Return the goal. It is not thread safe to return the ramping value.
        
        switch (address) {
            case EcholumeAudioTapParameterAddress::gain:
                return (AUValue)mGain;
                
            default: return 0.f;
        }
    }
    
    // MARK: - Max Frames
    AUAudioFrameCount maximumFramesToRender() const {
        return mMaxFramesToRender;
    }
    
    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) {
        mMaxFramesToRender = maxFrames;
    }
    
    // MARK: - Musical Context
    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock) {
        mMusicalContextBlock = contextBlock;
    }

    // MARK: - MIDI Output
    void setMIDIOutputEventBlock(AUMIDIEventListBlock midiOutBlock) {
        mMIDIOutBlock = midiOutBlock;
    }

    // MARK: - MIDI Protocol
    MIDIProtocolID AudioUnitMIDIProtocol() const {
        return kMIDIProtocol_2_0;
    }
    
    /**
     MARK: - Internal Process
     
     This function does the core siginal processing.
     Do your custom DSP here.
     */
    void process(std::span<float const*> inputBuffers, std::span<float *> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        assert(inputBuffers.size() == outputBuffers.size());

        // Read the host's tempo from the playhead (exact, phase-locked).
        if (mMusicalContextBlock) {
            double tempo = 0;
            mMusicalContextBlock(&tempo, nullptr, nullptr, nullptr, nullptr, nullptr);
            if (tempo > 0) { mOutBPM = (float)tempo; }
        }

        // Analyse channel 0 BEFORE writing output (output may alias input).
        if (!inputBuffers.empty() && inputBuffers[0] != nullptr && frameCount > 0) {
            const float *in0 = inputBuffers[0];
            const double aLow = 1.0 - std::exp(-2.0 * M_PI * 200.0 / mSampleRate);   // ~200 Hz
            const double aMid = 1.0 - std::exp(-2.0 * M_PI * 2000.0 / mSampleRate);  // ~2 kHz
            double sLevel = 0, sLow = 0, sMid = 0, sHigh = 0;
            for (UInt32 i = 0; i < frameCount; ++i) {
                double x = in0[i];
                mLPlow += aLow * (x - mLPlow);   // low-pass
                mLPmid += aMid * (x - mLPmid);   // low-pass (higher cutoff)
                double lowS = mLPlow;
                double highS = x - mLPmid;       // high-pass
                double midS = mLPmid - mLPlow;   // band-pass (200 Hz – 2 kHz)
                sLevel += x * x; sLow += lowS * lowS; sMid += midS * midS; sHigh += highS * highS;
            }
            double n = (double)frameCount;
            double rLevel = std::sqrt(sLevel / n), rLow = std::sqrt(sLow / n),
                   rMid = std::sqrt(sMid / n), rHigh = std::sqrt(sHigh / n);
            // Running per-band normalizers (slow decay) → output stays ~0…1 regardless of track gain.
            mNormLevel = std::fmax(mNormLevel * 0.9995, rLevel);
            mNormLow = std::fmax(mNormLow * 0.9995, rLow);
            mNormMid = std::fmax(mNormMid * 0.9995, rMid);
            mNormHigh = std::fmax(mNormHigh * 0.9995, rHigh);
            mOutLevel = (float)std::fmin(1.0, rLevel / (mNormLevel + 1e-5));
            mOutLow = (float)std::fmin(1.0, rLow / (mNormLow + 1e-5));
            mOutMid = (float)std::fmin(1.0, rMid / (mNormMid + 1e-5));
            mOutHigh = (float)std::fmin(1.0, rHigh / (mNormHigh + 1e-5));
            // The render thread only writes these floats; the Swift-side OSC
            // sender polls them (~60 Hz) and does the actual network I/O, so no
            // syscall ever runs on the realtime path.
        }

        // Pass the audio through unchanged (a tap, not a gate).
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                outputBuffers[channel][frameIndex] = inputBuffers[channel][frameIndex] * mGain;
            }
        }
    }

    // MARK: - Analysis output (polled by the Swift OSC sender; benign single-float races)
    float outLevel() const { return mOutLevel; }
    float outLow()   const { return mOutLow; }
    float outMid()   const { return mOutMid; }
    float outHigh()  const { return mOutHigh; }
    float outBPM()   const { return mOutBPM; }
    
    void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
        switch (event->head.eventType) {
            case AURenderEventParameter: {
                handleParameterEvent(now, event->parameter);
                break;
            }
                
            case AURenderEventMIDIEventList: {
                handleMIDIEventList(now, &event->MIDIEventsList);
                break;
            }
                
            default:
                break;
        }
    }
    
    void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {
        setParameter(parameterEvent.parameterAddress, parameterEvent.value);
    }
    
    void handleMIDIEventList(AUEventSampleTime now, AUMIDIEventList const* midiEvent) {
        auto visitor = [] (void* context, MIDITimeStamp timeStamp, MIDIUniversalMessage message) {
            auto thisObject = static_cast<EcholumeAudioTapDSPKernel *>(context);
            
            switch (message.type) {
                case kMIDIMessageTypeChannelVoice2: {
                    thisObject->handleMIDI2VoiceMessage(message);
                }
                    break;
                    
                default:
                    break;
            }
        };
        
        MIDIEventListForEachEvent(&midiEvent->eventList, visitor, this);
    }
    
    void handleMIDI2VoiceMessage(const struct MIDIUniversalMessage& message) {
        //const auto& note = message.channelVoice2.note;
        
        switch (message.channelVoice2.status) {
            case kMIDICVStatusNoteOff: {
                mNoteEnvelope = 0.0;
            }
                break;
                
            case kMIDICVStatusNoteOn: {
                mNoteEnvelope = 1.0;
            }
                break;
                
            default:
                break;
        }
    }
    
    // MARK: - Member Variables
    AUHostMusicalContextBlock mMusicalContextBlock;
    
    double mSampleRate = 44100.0;
    double mGain = 1.0;
    double mNoteEnvelope = 0.0;

    // Analysis state (render thread only).
    double mLPlow = 0.0, mLPmid = 0.0;
    double mNormLevel = 1e-4, mNormLow = 1e-4, mNormMid = 1e-4, mNormHigh = 1e-4;
    // Latest normalized features, polled by the Swift OSC sender (~60 Hz).
    float mOutLevel = 0, mOutLow = 0, mOutMid = 0, mOutHigh = 0, mOutBPM = 0;

    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;
    AUMIDIEventListBlock mMIDIOutBlock;
};
