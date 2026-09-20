import SwiftUI

struct LightweightPhotoPreviewView: View {
	let onPicked: (UIImage) -> Void
	let onBack: () -> Void
	let onAllPhotos: () -> Void
	@State private var photoModel: PhotoGridViewModel

	init(
		previewImages: [UIImage]? = nil, onPicked: @escaping (UIImage) -> Void,
		onBack: @escaping () -> Void, onAllPhotos: @escaping () -> Void
	) {
		_photoModel = State(initialValue: previewImages.map { PhotoGridViewModel(previewImages: $0) } ?? PhotoGridViewModel())
		self.onPicked = onPicked
		self.onBack = onBack
		self.onAllPhotos = onAllPhotos
	}

	init(
		photoModel: PhotoGridViewModel, onPicked: @escaping (UIImage) -> Void,
		onBack: @escaping () -> Void, onAllPhotos: @escaping () -> Void
	) {
		_photoModel = State(initialValue: photoModel)
		self.onPicked = onPicked
		self.onBack = onBack
		self.onAllPhotos = onAllPhotos
	}

	var body: some View {
		NavigationStack {
			PhotoGridView(viewModel: photoModel, onPicked: onPicked)
				.background(Color(.secondarySystemBackground))
				.overlay(alignment: .bottom) {
					PhotoPreviewControls(onBack: onBack, onAllPhotos: onAllPhotos)
						.background { Color.clear.contentShape(Rectangle()).onTapGesture {} }
				}
				.toolbar(.hidden, for: .navigationBar)
		}
	}
}

#Preview("Photos") {
	LightweightPhotoPreviewView(
		photoModel: PhotoGridViewModel(previewImages: PreviewPhotos.images),
		onPicked: { _ in }, onBack: {}, onAllPhotos: {})
}
