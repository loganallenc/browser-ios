/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Shared

protocol PicklistSettingDelegate {
    func picklistSetting(setting: PicklistSetting, pickedIndex: Int)
}


class PicklistSetting: UITableViewController {
    var options = [String]()
    var headerTitle = ""
    var delegate: PicklistSettingDelegate?
    var initialIndex = -1

    convenience init(options: [String], title: String, current: Int) {
        self.init(style: UITableViewStyle.Grouped)
        self.options = options
        self.headerTitle = title
        self.initialIndex = current
    }

    override init(style: UITableViewStyle) {
        super.init(style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: nil)
        cell.textLabel?.text = options[indexPath.row]
        if initialIndex == indexPath.row {
            cell.accessoryType = .Checkmark
        }
        return cell
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return headerTitle
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count ?? 0
    }

    override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        navigationController?.popViewControllerAnimated(true)
        delegate?.picklistSetting(self, pickedIndex: indexPath.row)
        return nil
    }

    // Don't show delete button on the left.
    override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return UITableViewCellEditingStyle.None
    }

    // Don't reserve space for the delete button on the left.
    override func tableView(tableView: UITableView, shouldIndentWhileEditingRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
}


