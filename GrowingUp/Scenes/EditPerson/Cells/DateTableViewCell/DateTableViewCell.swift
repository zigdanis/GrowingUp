//
//  DateTableViewCell.swift
//  GrowingUp
//
//  Created by zigdanis on 17/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol DateCellView: AnyObject {
  func display(title: String)
  func display(date: Date?)
  func setup(with delegate: DateCellDelegate?, forRow row: Int)
}

protocol DateCellDelegate: AnyObject {
  func dateCell(_ cell: DateCellView, didChangeBirthdayTo date: Date)
}

final class DateTableViewCell: UITableViewCell, DateCellView {

  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var datePicker: UIDatePicker!
  private weak var delegate: DateCellDelegate?
  private var row: Int?

  override func awakeFromNib() {
    super.awakeFromNib()
    selectionStyle = .none
    datePicker.datePickerMode = .dateAndTime
    datePicker.preferredDatePickerStyle = .compact
    datePicker.maximumDate = Date()
    datePicker.addTarget(self, action: #selector(dateChanged(sender:)), for: .valueChanged)
  }

  // MARK: - DateCellView

  func display(title: String) {
    titleLabel.text = title
  }

  func display(date: Date?) {
    guard let date = date else { return }
    datePicker.date = date
  }

  func setup(with delegate: DateCellDelegate?, forRow row: Int) {
    self.delegate = delegate
    self.row = row
  }

  // MARK: - Actions

  @objc
  private func dateChanged(sender: UIDatePicker) {
    delegate?.dateCell(self, didChangeBirthdayTo: sender.date)
  }

}
