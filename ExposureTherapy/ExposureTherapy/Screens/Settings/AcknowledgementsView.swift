//
//  AcknowledgementsView.swift
//  ExposureTherapy
//
//  Credits and licenses for the bundled fonts. The SIL Open Font License
//  requires shipping its text with the fonts.
//

import SwiftUI

struct AcknowledgementsView: View {
    private struct Credit: Identifiable {
        let name: String
        let licenseFile: String
        var id: String { name }

        /// The license text bundled in Resources/Licenses.
        var licenseText: String {
            guard let url = Bundle.main.url(forResource: licenseFile, withExtension: "txt"),
                  let text = try? String(contentsOf: url, encoding: .utf8)
            else { return "SIL Open Font License, Version 1.1 — https://openfontlicense.org" }
            return text
        }
    }

    private let credits = [
        Credit(name: "Bricolage Grotesque", licenseFile: "BricolageGrotesque-OFL"),
        Credit(name: "Inter", licenseFile: "Inter-OFL"),
    ]

    var body: some View {
        List {
            ForEach(credits) { credit in
                Section(credit.name) {
                    Text(credit.licenseText)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.muted)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AcknowledgementsView()
    }
}
