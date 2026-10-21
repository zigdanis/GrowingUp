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
	let viewModel: PhotoGridViewModel
	let onPicked: (UIImage) -> Void

	@State private var showLimitedPicker = false

	private let spacing: CGFloat = 2
	/// Wider windows, such as an unfolded iPhone Duo, get more columns rather than ever-larger thumbnails.
	private let minimumThumbnailSide: CGFloat = 120

	var body: some View {
		content
			.task { await viewModel.onAppear() }
			.onDisappear { viewModel.cancelSelection() }
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
			.background(Color(.secondarySystemBackground))
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
			let count = columnCount(for: proxy.size.width)
			let side = (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
			ScrollView {
				if viewModel.authState == .limited {
					LimitedAccessHeader { showLimitedPicker = true }
				}
				LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: count), spacing: spacing) {
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

	/// Three columns at every iPhone portrait width (up to 440 pt), more once the window is wider.
	private func columnCount(for width: CGFloat) -> Int {
		max(3, Int((width + spacing) / (minimumThumbnailSide + spacing)))
	}
}
