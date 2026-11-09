extension PeoplePresenter {
	/// What follows each change the presenter stores, a save, a new order or a restore: the widgets reload, and the iCloud
	/// backup follows a moment later.
	static func storedPeopleChanged(reloadWidgets: @escaping () -> Void, configurator: SceneConfigurator) -> () -> Void {
		{
			reloadWidgets()
			configurator.libraryChanged()
		}
	}

	/// The library of stored people, whose first read the iCloud backup takes too. The backup writes nothing before the
	/// people are read, nor while reading them fails.
	static func makeLibrary(configurator: SceneConfigurator) -> PeopleLibrary {
		let library = PeopleLibrary(
			fetch: configurator.fetchUseCase.fetchPersons, analytics: configurator.analytics, onLoaded: configurator.libraryChanged)
		configurator.iCloudBackup?.start { [weak library] in library?.state == .loaded }
		return library
	}
}
