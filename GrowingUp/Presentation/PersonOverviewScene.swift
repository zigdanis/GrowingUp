import Core
import SwiftUI

struct PersonOverviewScene: View {
	let person: Person
	let isSelected: Bool
	/// Turns the page into its in-place edit mode; a tap anywhere on the page does it, as there is no visible button.
	let onEdit: () -> Void
	/// Returns to the mosaic, for VoiceOver's escape gesture and actions.
	let onClose: () -> Void
	/// Pages to the next or previous person, for VoiceOver, which reads people without swiping; nil at that end.
	let onNext: (() -> Void)?
	let onPrevious: (() -> Void)?
	let safeAreaInsets: EdgeInsets
	let layout: PersonPageLayout
	/// The whole window, safe areas included, since the page draws edge to edge.
	let pageSize: CGSize
	let now: () -> Date
	@State private var presenter: OverviewPresenter
	@State private var burstStarted: Date?
	/// VoiceOver lands on the age of a page the pager arrives at, such as after its "Next person" action.
	@AccessibilityFocusState private var isAgeFocused: Bool
	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	init(
		person: Person, isSelected: Bool, configurator: SceneConfigurator, safeAreaInsets: EdgeInsets, layout: PersonPageLayout,
		pageSize: CGSize, onEdit: @escaping () -> Void, onClose: @escaping () -> Void, onNext: (() -> Void)?,
		onPrevious: (() -> Void)?
	) {
		self.person = person
		self.isSelected = isSelected
		self.onEdit = onEdit
		self.onClose = onClose
		self.onNext = onNext
		self.onPrevious = onPrevious
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
			case .widePortrait where layout.spansFold(idiom: UIDevice.current.userInterfaceIdiom):
				// Keeps the age above the middle, where a partly folded iPhone Duo bends.
				pageContent(maxAgeHeight: pageSize.height * 0.42)
					.frame(maxWidth: layout.columnWidth)
					.padding(.leading, safeAreaInsets.leading)
					.padding(.trailing, safeAreaInsets.trailing)
			case .widePortrait:
				// No fold crosses an iPad: the whole photo shows, with the age in a column along the leading edge.
				pageContent()
					.frame(maxWidth: layout.columnWidth)
					.frame(maxWidth: .infinity, alignment: .leading)
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
		// The whole page is the way into edit mode; a tap never competes with the pager's swipes or the zoom's drag down.
		.contentShape(Rectangle())
		.onTapGesture(perform: onEdit)
		.onChange(of: presenter.celebrationID) { _, _ in
			burstStarted = reduceMotion ? nil : Date()
		}
		.task(id: burstStarted) {
			guard burstStarted != nil else { return }
			do { try await Task.sleep(for: .seconds(ConfettiStyle.duration)) } catch { return }
			burstStarted = nil
		}
		.task(id: PersonPictureCandidates.ids(of: person)) { await presenter.load(person: person) }
		.onChange(of: isSelected) { _, selected in
			if selected { isAgeFocused = true }
		}
		.onChange(of: person) { _, changedPerson in
			// Neighbouring pages also need fresh age and accessibility text after a saved change.
			presenter.tick(person: changedPerson, now: now(), isSelected: isSelected)
		}
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
	}

	/// The age at the top and the birthday card at the bottom, with the middle left to the photo.
	private func pageContent(maxAgeHeight: CGFloat? = nil) -> some View {
		VStack(spacing: 0) {
			ViewThatFits(in: .vertical) {
				ageCard
				ScrollView { ageCard }
					.scrollBounceBehavior(.basedOnSize)
			}
			.frame(maxHeight: maxAgeHeight, alignment: .top)
			// Second after the card: the age takes the height the card leaves, scrolling when it does not fit.
			.layoutPriority(1)
			Spacer(minLength: 24)
			if person.celebratesBirthdays {
				// At the largest text sizes the countdown wraps and the line grows rather than truncating it.
				BirthdayLine(birthdayText: presenter.birthdayText, isShown: isSelected)
					.padding(.horizontal, 24)
					.padding(.bottom, 16)
					// The line gets its full height first, ahead of the age above it.
					.layoutPriority(2)
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
	}

	private var photo: some View {
		ZStack {
			Color.black
			photoOrMonogram
			scrim
		}
	}

	/// The photo whole on the leading half; on the trailing half, the same photo blurred and dimmed behind the age and controls.
	private var panes: some View {
		HStack(spacing: 0) {
			ZStack {
				Color.black
				photoOrMonogram
			}
			.frame(width: pageSize.width / 2)
			ZStack {
				Color.black
				if let image = presenter.image {
					filling(image).blur(radius: 60, opaque: true)
				} else if presenter.showsMonogram {
					PersonMonogram(id: person.id, name: person.name).blur(radius: 60, opaque: true)
				}
				Color.black.opacity(0.45)
				scrim
			}
		}
	}

	/// The photo, or the monogram once no photo loads; black while one loads, so a photo never flashes the monogram first.
	@ViewBuilder private var photoOrMonogram: some View {
		if let image = presenter.image {
			filling(image)
		} else if presenter.showsMonogram {
			PersonMonogram(id: person.id, name: person.name)
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

	/// Darkens the top behind the age and, more strongly, the bottom behind the birthday line,
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
			secondaryText: presenter.secondaryText, tickerText: presenter.tickerText, accessibilityAge: presenter.accessibilityAge,
			isShown: isSelected
		)
		// VoiceOver reaches edit mode and the mosaic through the age, the page's main element; activating it edits,
		// like a tap anywhere on the page.
		.accessibilityAction(.default, onEdit)
		.accessibilityAction(named: Text("Edit"), onEdit)
		.accessibilityActions {
			if let onNext {
				Button("Next person", action: onNext)
			}
			if let onPrevious {
				Button("Previous person", action: onPrevious)
			}
		}
		.accessibilityAction(named: Text("All people"), onClose)
		.accessibilityAction(.escape, onClose)
		.accessibilityFocused($isAgeFocused)
		.padding(.horizontal, 24)
	}
}
