import Core
import SwiftUI

struct PersonOverviewScene: View {
	let person: Person
	let isSelected: Bool
	let onEdit: () -> Void
	let safeAreaInsets: EdgeInsets
	let now: () -> Date
	@State private var presenter: OverviewPresenter
	@State private var showingBirthday = false
	@State private var burstStarted: Date?
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	init(
		person: Person, isSelected: Bool, configurator: SceneConfigurator, safeAreaInsets: EdgeInsets, onEdit: @escaping () -> Void
	) {
		self.person = person
		self.isSelected = isSelected
		self.onEdit = onEdit
		self.safeAreaInsets = safeAreaInsets
		now = configurator.now
		_presenter = State(initialValue: OverviewPresenter(loadImage: configurator.loadImage))
	}

	var body: some View {
		ZStack(alignment: .topTrailing) {
			Button(action: onEdit) {
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
					LinearGradient(
						colors: [.black.opacity(0.45), .clear, .black.opacity(0.65)],
						startPoint: .top, endPoint: .bottom)
					VStack(spacing: 20) {
						Text(person.name).font(.largeTitle.bold()).accessibilityIdentifier("person.name")
						Text(presenter.age).font(.title2).multilineTextAlignment(.center)
							.accessibilityIdentifier("person.age")
						Spacer()
					}
					.padding(24)
					.padding(.top, safeAreaInsets.top)
					.padding(.bottom, safeAreaInsets.bottom)
					.foregroundStyle(.white)
				}
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.accessibilityElement(children: .contain)
			.accessibilityLabel(Text("Edit person"))
			.accessibilityIdentifier("person.edit")
			if let status = presenter.birthdayStatus, status.isUpcoming {
				Button("Birthday", systemImage: "birthday.cake.fill") { showingBirthday = true }
					.labelStyle(.iconOnly)
					.font(.title2)
					.foregroundStyle(.white)
					.frame(width: 44, height: 44)
					.background(.black.opacity(0.25), in: Circle())
					.padding(.trailing, 16)
					.padding(.top, safeAreaInsets.top + 18)
					.accessibilityIdentifier("person.birthday")
					.popover(isPresented: $showingBirthday, arrowEdge: .top) {
						BirthdayInfoView(status: presenter.birthdayStatus ?? status)
							.presentationCompactAdaptation(.popover)
					}
			}
			if let burstStarted, isSelected, !reduceMotion {
				BirthdayConfettiView(started: burstStarted)
					.accessibilityElement(children: .ignore)
					.accessibilityLabel(Text("Happy birthday!"))
					.accessibilityIdentifier("person.confetti")
					.accessibilityValue(String(presenter.celebrationID))
					.allowsHitTesting(false)
			}
		}
		.ignoresSafeArea(.container)
		.onChange(of: presenter.celebrationID) { _, _ in
			burstStarted = reduceMotion ? nil : Date()
		}
		.task(id: burstStarted) {
			guard burstStarted != nil else { return }
			do { try await Task.sleep(for: .seconds(3.5)) } catch { return }
			burstStarted = nil
		}
		.task(id: person.appPicId) { await presenter.load(person: person) }
		.task(id: isSelected ? person.birthday : nil) {
			while !Task.isCancelled {
				presenter.tick(person: person, now: now(), isSelected: isSelected)
				guard isSelected else { break }
				do { try await Task.sleep(for: .seconds(1)) } catch { break }
			}
		}
		.sceneError($presenter.error)
	}
}
