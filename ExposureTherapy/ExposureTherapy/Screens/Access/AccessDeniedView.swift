//
//  AccessDeniedView.swift
//  ExposureTherapy
//
//  SPEC.md → Data → Photo access. Full-screen explainer when photo access
//  is denied or restricted.
//

import SwiftUI

struct AccessDeniedView: View {
    var body: some View {
        AccessScreenLayout {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.rose)
                .accessibilityHidden(true)

            Text("We can't see your photos.")
                .font(.bricolage(34, relativeTo: .largeTitle))
                .foregroundStyle(.plum)
                .accessibilityAddTraits(.isHeader)

            Text("Exposure Therapy needs access to your photo library to show you photos. Turn it on in Settings under Photos, then come back.")
                .font(.inter(16))
                .foregroundStyle(.muted)
        } action: {
            OpenSettingsButton()
                .buttonStyle(.pill)
        }
    }
}

#Preview {
    AccessDeniedView()
}
