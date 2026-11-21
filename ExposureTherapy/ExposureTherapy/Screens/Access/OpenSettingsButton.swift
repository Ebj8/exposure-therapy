//
//  OpenSettingsButton.swift
//  ExposureTherapy
//
//  Opens this app's page in the Settings app, where photo access is changed.
//

import SwiftUI
import UIKit

struct OpenSettingsButton<Label: View>: View {
    @Environment(\.openURL) private var openURL
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            label()
        }
    }
}

extension OpenSettingsButton where Label == Text {
    init() {
        self.init { Text("Open Settings") }
    }
}

#Preview {
    OpenSettingsButton()
        .buttonStyle(.pill)
        .padding()
        .background(.cream)
}
