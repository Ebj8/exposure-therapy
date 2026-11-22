//
//  WelcomeView.swift
//  ExposureTherapy
//
//  SPEC.md → Data → Photo access. Shown on first launch, before iOS asks
//  for photo access.
//

import Photos
import SwiftUI

struct WelcomeView: View {
    @Environment(PhotoLibrary.self) private var library

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.blockLoose) {
            Spacer()

            Image("AppIconImage")
                .resizable()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityHidden(true)

            Text("Your camera roll has some explaining to do.")
                .font(.bricolage(34, relativeTo: .largeTitle))
                .foregroundStyle(.plum)
                .accessibilityAddTraits(.isHeader)

            Text("Exposure Therapy shows your photos one at a time so you can decide which to keep. Nothing leaves your iPhone.")
                .font(.inter(16))
                .foregroundStyle(.muted)

            Spacer()

            Button("Allow photo access") {
                Task { await library.requestAccess() }
            }
            .buttonStyle(.pill)
        }
        .padding(Spacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.cream)
    }
}

#Preview {
    WelcomeView()
        .environment(PhotoLibrary(previewIndex: .empty, authorization: .notDetermined))
}
