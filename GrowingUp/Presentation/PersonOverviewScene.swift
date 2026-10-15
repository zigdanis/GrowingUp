import Core
import SwiftUI

struct PersonOverviewScene: View {
	let person: Person
	let isSelected: Bool
	let onEdit: () -> Void
	let onCardHeightChange: (CGFloat) -> Void
	let safeAreaInsets: EdgeInsets
	let now: () -> Date
	@State private var presenter: OverviewPresenter
	@State private var burstStarted: Date?
	@State private var editPresses = 0
	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	init(
		person: Person, isSelected: Bool, configurator: SceneConfigurator, safeAreaInsets: EdgeInsets, onEdit: @escaping () -> Void,
		onCardHeightChange: @escaping (CGFloat) -> Void
	) {
		self.person = person
		self.isSelected = isSelected
		self.onEdit = onEdit
		self.onCardHeightChange = onCardHeightChange
		self.safeAreaInsets = safeAreaInsets
		now = configurator.now
		_presenter = State(initialValue: OverviewPresenter(loadImage: configurator.loadImage))
	}

	var body: some View {
		ZStack {
			photo
			VStack(spacing: 0) {
				ViewThatFits(in: .vertical) {
					// Lets a long press on the age reach the photo below.
					ageCard.allowsHitTesting(false)
					ScrollView { ageCard }
						.scrollBounceBehavior(.basedOnSize)
				}
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
		.task(id: isSelected ? person.birthday : nil) {
			while !Task.isCancelled {
				presenter.tick(person: person, now: now(), isSelected: isSelected)
				guard isSelected else { break }
				do { try await Task.sleep(for: .seconds(1)) } catch { break }
			}
		}
		.sceneError($presenter.error)
	}

	private var photo: some View {
		ZStack {
			Color.black
			if let image = presenter.image {
				GeometryReader { geometry in
					Image(uiImage: image)
						.resizable()
						.scaledToFill()
						.frame(width: geometry.size.width, height: geometry.size.height)
						.clipped()
				}
			} else {
				LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
				Text("🤷").font(.system(size: 100))
			}
			// Darkens the top behind the age and, more strongly, the bottom behind the strip and card,
			// so white text stays readable on very light photos.
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
		.accessibilityHidden(true)
		.contentShape(Rectangle())
		// A secondary way into the editor; the Edit button is the visible and accessible one.
		.onLongPressGesture {
			editPresses += 1
			onEdit()
		}
	}

	private var ageCard: some View {
		PersonAgeCard(
			name: person.name, primaryValue: presenter.primaryValue, primaryUnit: presenter.primaryUnit,
			secondaryText: presenter.secondaryText, tickerText: presenter.tickerText, accessibilityAge: presenter.accessibilityAge
		)
		.padding(.horizontal, 24)
	}
}
