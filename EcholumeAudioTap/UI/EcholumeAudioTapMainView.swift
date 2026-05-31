//
//  EcholumeAudioTapMainView.swift
//  EcholumeAudioTap
//
//  Created by Jarl Lyng on 31/05/2026.
//

import SwiftUI

struct EcholumeAudioTapMainView: View {
    var parameterTree: ObservableAUParameterGroup

    var body: some View {
        ParameterSlider(param: parameterTree.global.gain)
    }
}
