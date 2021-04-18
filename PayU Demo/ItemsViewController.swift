//
//  MasterViewController.swift
//  PayU Demo
//
//  Copyright © 2019 PayU. All rights reserved.
//

import UIKit

class ItemsViewController: UITableViewController {

    var detailViewController: CheckoutViewController? = nil
    var objects = [Item]()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.backgroundColor = AppBranding.primaryColor
        navigationController?.navigationBar.tintColor = AppBranding.secondaryColor
        
        objects = [
            Item(name: "Hot dog", price: 1000),
            Item(name: "Pizza", price: 2000),
            Item(name: "Donut", price: 500)
        ]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    // MARK: - Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showCheckout" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let object = objects[indexPath.row]
                let controller = segue.destination as! CheckoutViewController
                controller.detailItem = object
            }
        }
    }

    // MARK: - Table View
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        let item = objects[indexPath.row]
        cell.textLabel!.text = item.name
        cell.textLabel?.font = AppBranding.font!
        return cell
    }
}
