//
//  ImagePickersTableViewCell.swift
//  GrowingUp
//
//  Created by zigdanis on 22/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Core
import UIKit

protocol ImagesCellView: AnyObject {
  func display(appPic: PersonImage?)
  func display(widgetPic: PersonImage?)
  func setup(with delegate: ImagesCellViewDelegate, forRow row: Int)
}

protocol ImagesCellViewDelegate: AnyObject {
  func showAppPicImagePickerFor(row: Int, source: ImageCaptureSource)
  func showWidgetPicImagePickerFor(row: Int, source: ImageCaptureSource)
  func removeAppPic(forRow row: Int)
  func removeWidgetPic(forRow row: Int)
}

final class ImagesTableViewCell: UITableViewCell, ImagesCellView {
  @IBOutlet weak var appPicButton: ImagePickerButton!
  @IBOutlet weak var widgetPicButton: ImagePickerButton!
  @IBOutlet weak var appPicLabel: UILabel!
  @IBOutlet weak var widgetPicLabel: UILabel!
  private weak var delegate: ImagesCellViewDelegate?
  private var row: Int?
  private let appPicRemoveBadge = ImagesTableViewCell.makeRemoveBadge()
  private let widgetPicRemoveBadge = ImagesTableViewCell.makeRemoveBadge()
  private let appPicMenuButton = ImagesTableViewCell.makeSourceMenuButton()
  private let widgetPicMenuButton = ImagesTableViewCell.makeSourceMenuButton()

  override func awakeFromNib() {
    super.awakeFromNib()
    selectionStyle = .none
    setupImagePickerViews()
    setupPickerButtons()
    setupRemoveBadges()
  }

  private func setupImagePickerViews() {
    appPicLabel.text = String(localized: "main pic")
    widgetPicLabel.text = String(localized: "widget pic")
  }

  private func setupPickerButtons() {
    addMenuButton(appPicMenuButton, over: appPicButton)
    addMenuButton(widgetPicMenuButton, over: widgetPicButton)
    appPicMenuButton.accessibilityLabel = String(localized: "Change app picture")
    widgetPicMenuButton.accessibilityLabel = String(localized: "Change widget picture")
    appPicButton.isUserInteractionEnabled = false
    widgetPicButton.isUserInteractionEnabled = false
  }

  private func addMenuButton(_ menuButton: UIButton, over pickerButton: UIButton) {
    menuButton.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(menuButton)
    NSLayoutConstraint.activate([
      menuButton.topAnchor.constraint(equalTo: pickerButton.topAnchor),
      menuButton.leadingAnchor.constraint(equalTo: pickerButton.leadingAnchor),
      menuButton.trailingAnchor.constraint(equalTo: pickerButton.trailingAnchor),
      menuButton.bottomAnchor.constraint(equalTo: pickerButton.bottomAnchor)
    ])
  }

  private func setupRemoveBadges() {
    addRemoveBadge(appPicRemoveBadge, over: appPicButton, action: #selector(removeAppPicTouched))
    addRemoveBadge(widgetPicRemoveBadge, over: widgetPicButton, action: #selector(removeWidgetPicTouched))
  }

  // The badge lives in the content view, not inside the picker button: the
  // button applies a circular layer mask that would clip any subview of it.
  private func addRemoveBadge(_ badge: UIButton, over pickerButton: UIButton, action: Selector) {
    badge.addTarget(self, action: action, for: .touchUpInside)
    contentView.addSubview(badge)
    NSLayoutConstraint.activate([
      badge.widthAnchor.constraint(equalToConstant: 24),
      badge.heightAnchor.constraint(equalToConstant: 24),
      badge.topAnchor.constraint(equalTo: pickerButton.topAnchor, constant: 4),
      badge.trailingAnchor.constraint(equalTo: pickerButton.trailingAnchor, constant: -4)
    ])
  }

  private static func makeRemoveBadge() -> UIButton {
    let button = UIButton(type: .system)
    var config = UIButton.Configuration.plain()
    let symbol = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
    config.image = UIImage(systemName: "xmark", withConfiguration: symbol)
    config.baseForegroundColor = .white
    config.background.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    config.background.cornerRadius = 12
    button.configuration = config
    button.translatesAutoresizingMaskIntoConstraints = false
    button.isHidden = true
    button.accessibilityLabel = String(localized: "Remove")
    return button
  }

  private static func makeSourceMenuButton() -> UIButton {
    let button = UIButton(type: .custom)
    button.showsMenuAsPrimaryAction = true
    button.backgroundColor = .clear
    return button
  }

  // MARK: - ImagesCellView

  func display(appPic: PersonImage?) {
    appPicRemoveBadge.isHidden = (appPic == nil)
    guard let appPic = appPic else {
      appPicButton.drawImage(nil)
      return
    }
    if let uiImage = appPic.uiImage {
      appPicButton.drawImage(uiImage)
    } else {
      ImagesCache.loadImageFromDiskOrMemory(image: appPic) { result in
        switch result {
        case .success(let img):
          self.appPicButton.drawImage(img)
        case .failure(let error):
          Logging.logError(error)
        }
      }
    }
  }

  func display(widgetPic: PersonImage?) {
    widgetPicRemoveBadge.isHidden = (widgetPic == nil)
    guard let widgetPic = widgetPic else {
      widgetPicButton.drawImage(nil)
      return
    }
    if let uiImage = widgetPic.uiImage {
      widgetPicButton.drawImage(uiImage)
    } else {
      ImagesCache.loadImageFromDiskOrMemory(image: widgetPic) { result in
        switch result {
        case .success(let img):
          self.widgetPicButton.drawImage(img)
        case .failure(let error):
          Logging.logError(error)
        }
      }
    }
  }

  func setup(with delegate: ImagesCellViewDelegate, forRow row: Int) {
    self.delegate = delegate
    self.row = row
    appPicMenuButton.menu = imageSourceMenu { [weak self] source in
      guard let self, let row = self.row else { return }
      self.delegate?.showAppPicImagePickerFor(row: row, source: source)
    }
    widgetPicMenuButton.menu = imageSourceMenu { [weak self] source in
      guard let self, let row = self.row else { return }
      self.delegate?.showWidgetPicImagePickerFor(row: row, source: source)
    }
  }

  // MARK: - Actions

  private func imageSourceMenu(onSelect: @escaping (ImageCaptureSource) -> Void) -> UIMenu {
    UIMenu(children: [
      UIAction(title: String(localized: "Camera"), image: UIImage(systemName: "camera")) { _ in
        onSelect(.camera)
      },
      UIAction(title: String(localized: "Photos"), image: UIImage(systemName: "photo")) { _ in
        onSelect(.photos)
      }
    ])
  }

  @objc
  private func removeAppPicTouched() {
    guard let row = row else { return }
    delegate?.removeAppPic(forRow: row)
  }

  @objc
  private func removeWidgetPicTouched() {
    guard let row = row else { return }
    delegate?.removeWidgetPic(forRow: row)
  }
}
