//
//  PhotoGridView.swift
//  GrowingUp
//
//  Custom PhotoKit grid with full -> limited -> denied/restricted handling.
//  Single-select: a tap loads the full-resolution image and reports it upward.
//

import Photos
import SwiftUI

struct PhotoGridView: View {
    let onPicked: (UIImage) -> Void

    @State private var viewModel = PhotoGridViewModel()
    @State private var showLimitedPicker = false

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 3
    )

    var body: some View {
        content
            .task { await viewModel.onAppear() }
            .overlay {
                if viewModel.isPreparingSelection {
                    SelectionProgressOverlay(progress: viewModel.selectionProgress) {
                        viewModel.cancelSelection()
                    }
                }
            }
            .alert("Couldn't load photo", isPresented: errorBinding) {
            } message: {
                Text("The photo couldn't be loaded. Try again or pick another.")
            }
            .background(
                LimitedLibraryPickerPresenter(isPresented: $showLimitedPicker) { viewController in
                    viewModel.presentLimitedPicker(from: viewController)
                }
            )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.selectionFailed },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }

    @ViewBuilder private var content: some View {
        switch viewModel.authState {
        case .notDetermined:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .full, .limited:
            grid
        case .denied:
            PermissionExplainerView(config: .photosDenied)
        case .restricted:
            PermissionExplainerView(config: .photosRestricted)
        }
    }

    private var grid: some View {
        GeometryReader { proxy in
            let side = (proxy.size.width - 4) / 3
            ScrollView {
                if viewModel.authState == .limited {
                    LimitedAccessHeader { showLimitedPicker = true }
                }
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(viewModel.assets) { asset in
                        PhotoThumbnailCell(
                            asset: asset,
                            side: side,
                            viewModel: viewModel
                        ) {
                            viewModel.select(asset, completion: onPicked)
                        }
                    }
                }
            }
        }
    }
}

/// Blocking overlay shown while a tapped photo's full-resolution image loads.
/// Shows a determinate bar once iCloud download progress is known, a spinner
/// otherwise, and a Cancel button so a slow download never traps the user.
private struct SelectionProgressOverlay: View {
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if progress > 0 && progress < 1 {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 160)
            } else {
                ProgressView()
            }
            Button("Cancel", action: onCancel)
                .font(.subheadline.weight(.semibold))
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct LimitedAccessHeader: View {
    let onSelectMore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checklist")
                .foregroundStyle(.secondary)
            Text("You've allowed access to a limited set of photos.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Select More", action: onSelectMore)
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

/// Bridges `presentLimitedLibraryPicker(from:)`, which requires a
/// UIViewController, into SwiftUI without reaching for shared application state.
private struct LimitedLibraryPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let present: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        guard isPresented else { return }
        DispatchQueue.main.async {
            present(viewController)
            isPresented = false
        }
    }
}
