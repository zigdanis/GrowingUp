import Core
import SwiftUI

struct PersonOverviewScene: View {
	let person: Person
	let isSelected: Bool
	let onEdit: () -> Void
	let onCardHeightChange: (CGFloat) -> Void
	let safeAreaInsets: EdgeInsets
	let layout: PersonPageLayout
	/// The whole window, safe areas included, since the page draws edge to edge.
	let pageSize: CGSize
	let now: () -> Date
	@State private var presenter: OverviewPresenter
	@State private var burstStarted: Date?
	@State private var editPresses = 0
	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	init(
		person: Person, isSelected: Bool, configurator: SceneConfigurator, safeAreaInsets: EdgeInsets, layout: PersonPageLayout,
		pageSize: CGSize, onEdit: @escaping () -> Void, onCardHeightChange: @escaping (CGFloat) -> Void
	) {
		self.person = person
		self.isSelected = isSelected
		self.onEdit = onEdit
		self.onCardHeightChange = onCardHeightChange
		self.safeAreaInsets = safeAreaInsets
		self.layout = layout
		self.pageSize = pageSize
		now = configurator.now
		_presenter = State(initialValue: OverviewPresenter(loadImage: configurator.loadImage))
	}

	var body: some View {
		ZStack {
			background
			switch layout {
			case .phone:
				pageContent()
			case .widePortrait:
				// Keeps the age above the middle, where a partly folded iPhone Duo bends.
				pageContent(maxAgeHeight: pageSize.height * 0.42)
					.frame(maxWidth: layout.columnWidth)
					.padding(.leading, safeAreaInsets.leading)
					.padding(.trailing, safeAreaInsets.trailing)
			case .landscape:
				// Everything stays on the trailing half, clear of the fold between the two panes.
				pageContent()
					.frame(maxWidth: layout.columnWidth)
					.padding(.trailing, safeAreaInsets.trailing)
					.frame(width: pageSize.width / 2)
					.frame(maxWidth: .infinity, alignment: .trailing)
			}
			if let burstStarted, isSelected, !reduceMotion {
				BirthdayConfettiView(started: burstStarted, celebration: presenter.celebrationID)
					.accessibilityElement(children: .ignore)
					.accessibilityLabel(Text("Happy birthday!"))
					.accessibilityIdentifier("person.confetti")
					.accessibilityValue(String(presenter.celebrationID))
					.allowsHitTesting(false)
			}
		}
		.ignoresSafeArea(.container)
		.sensoryFeedback(.impact(weight: .medium), trigger: editPresses)
		.onChange(of: presenter.celebrationID) { _, _ in
			burstStarted = reduceMotion ? nil : Date()
		}
		.task(id: burstStarted) {
			guard burstStarted != nil else { return }
			do { try await Task.sleep(for: .seconds(ConfettiStyle.duration)) } catch { return }
			burstStarted = nil
		}
		.task(id: person.appPicId) { await presenter.load(person: person) }
		.onDisappear {
			presenter.tick(person: person, now: now(), isSelected: false)
		}
		// Restart with every saved change so the ticking loop never reads a stale birthday or celebration choice.
		.task(id: isSelected ? person : nil) {
			while !Task.isCancelled {
				presenter.tick(person: person, now: now(), isSelected: isSelected)
				guard isSelected else { break }
				do { try await Task.sleep(for: .seconds(1)) } catch { break }
			}
		}
		.sceneError($presenter.error)
	}

	/// The age at the top and the birthday card at the bottom, with the middle left to the photo.
	private func pageContent(maxAgeHeight: CGFloat? = nil) -> some View {
		VStack(spacing: 0) {
			ViewThatFits(in: .vertical) {
				// Lets a long press on the age reach the photo below.
				ageCard.allowsHitTesting(false)
				ScrollView { ageCard }
					.scrollBounceBehavior(.basedOnSize)
			}
			.frame(maxHeight: maxAgeHeight, alignment: .top)
			.layoutPriority(1)
			// Leaves room for the avatar strip that floats above the card.
			Spacer(minLength: 72)
			BirthdayCard(birthdayText: presenter.birthdayText, onEdit: onEdit)
				.padding(.horizontal, 16)
				.padding(.bottom, 12)
				.onGeometryChange(for: CGFloat.self) { proxy in
					proxy.size.height
				} action: { height in
					onCardHeightChange(height)
				}
		}
		.padding(.top, safeAreaInsets.top + 16)
		.padding(.bottom, safeAreaInsets.bottom)
	}

	private var background: some View {
		Group {
			if layout == .landscape { panes } else { photo }
		}
		.accessibilityHidden(true)
		.contentShape(Rectangle())
		// A secondary way into the editor; the Edit button is the visible and accessible one.
		.onLongPressGesture {
			editPresses += 1
			onEdit()
		}
	}

	private var photo: some View {
		ZStack {
			Color.black
			photoOrPlaceholder
			scrim
		}
	}

	/// The photo whole on the leading half; on the trailing half, the same photo blurred and dimmed behind the age and controls.
	private var panes: some View {
		HStack(spacing: 0) {
			ZStack {
				Color.black
				photoOrPlaceholder
			}
			.frame(width: pageSize.width / 2)
			ZStack {
				Color.black
				if let image = presenter.image {
					filling(image).blur(radius: 60, opaque: true)
				} else {
					placeholder
				}
				Color.black.opacity(0.45)
				scrim
			}
		}
	}

	@ViewBuilder private var photoOrPlaceholder: some View {
		if let image = presenter.image {
			filling(image)
		} else {
			placeholder
			Text("🤷").font(.system(size: 100))
		}
	}

	private func filling(_ image: UIImage) -> some View {
		GeometryReader { geometry in
			Image(uiImage: image)
				.resizable()
				.scaledToFill()
				.frame(width: geometry.size.width, height: geometry.size.height)
				.clipped()
		}
	}

	private var placeholder: some View {
		LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
	}

	/// Darkens the top behind the age and, more strongly, the bottom behind the strip and card,
	/// so white text stays readable on very light photos.
	private var scrim: some View {
		LinearGradient(
			stops: [
				.init(color: .black.opacity(0.55), location: 0),
				.init(color: .black.opacity(0.15), location: 0.35),
				.init(color: .clear, location: 0.5),
				.init(color: .black.opacity(0.3), location: 0.68),
				.init(color: .black.opacity(0.8), location: 1)
			],
			startPoint: .top, endPoint: .bottom)
	}

	private var ageCard: some View {
		PersonAgeCard(
			name: person.name, primaryValue: presenter.primaryValue, primaryUnit: presenter.primaryUnit,
			secondaryText: presenter.secondaryText, tickerText: presenter.tickerText, accessibilityAge: presenter.accessibilityAge
		)
		.padding(.horizontal, 24)
	}
}
