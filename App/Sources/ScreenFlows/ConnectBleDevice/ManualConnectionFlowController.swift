//
//  Created by David Laubenstein on 16.04.19.
//  Copyright © 2019 Jamit Labs GmbH. All rights reserved.
//

import CoreBluetooth
import Imperio
import SnapKit
import SwiftEntryKit
import UIKit

class ManualConnectionFlowController: FlowController {
    private lazy var navigationCtrl = UINavigationController(rootViewController: manualConnectionTableViewCtrl)

    private lazy var manualConnectionTableViewCtrl: ManualConnectionTableViewController = {
        let manualConnectionTableViewCtrl = ManualConnectionTableViewController()
        manualConnectionTableViewCtrl.flowDelegate = self

        return manualConnectionTableViewCtrl
    }()

    override func start(from presentingViewController: UIViewController) {
        super.start(from: presentingViewController)
        presentingViewController.present(navigationCtrl, animated: true, completion: nil)
    }
}

extension ManualConnectionFlowController: ManualConnectionFlowDelegate {
    func startSearch() {
        manualConnectionTableViewCtrl.viewModel.sections[2].peripherals = []
        BluetoothConnector.global.startDiscovery()
    }

    func stopSearch() {
        BluetoothConnector.global.stopDiscovery()
    }

    func connect(with peripheral: CBPeripheral) {
        BluetoothConnector.global.connect(to: peripheral)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(isConnected(_:)),
            name: BluetoothConnectorNotificationPostMaster.didUpdateConnectionNotification,
            object: nil
        )
    }

    @objc
    func isConnected(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            NotificationCenter.default.removeObserver(self)
            guard let name = BluetoothConnector.global.connectedPeripheral?.name else { return }
            SwiftEntryKitOptions.addTopFloatMessage(
                title: SwiftEntryKitOptions.StyledString(
                    message: "Successfully connected",
                    font: UIFont.systemFont(ofSize: 12, weight: .regular),
                    color: Colors.GrayScale.white
                ),
                description: SwiftEntryKitOptions.StyledString(
                    message: name,
                    font: UIFont.systemFont(ofSize: 16, weight: .bold),
                    color: Colors.GrayScale.white
                ),
                backgroundColor: Colors.Feedback.success
            )

            self.navigationCtrl.dismiss(animated: false) {
                BluetoothConnector.global.stopDiscovery()
            }
        }
    }
}
