//
//  Created by David on 06.04.2019.
//  Copyright © 2017 DavidLaubenstein. All rights reserved.
//

import ARKit
import SceneKit
import SnapKit
import UIKit

protocol MainFlowDelegate: class {
    func connectBleDevice()
    func prepareGameStart()
    func didPrepareGameStart()
}

class MainViewController: UIViewController, ARSessionDelegate {
    weak var flowDelegate: MainFlowDelegate?

    lazy var startPlayButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = Colors.Vibrants.softBlue
        button.layer.cornerRadius = 50
        button.setTitle("Start", for: .normal)
        button.addTarget(self, action: #selector(startButtonPressed), for: .touchUpInside)
        return button
    }()

    lazy var sceneView = ARSCNView()

    var contentController: VirtualContentController = TexturedFace()

    var currentFaceAnchor: ARFaceAnchor?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        // view.addSubview(header)
        sceneView.addSubview(startPlayButton)
        view.addSubview(sceneView)
        setupNavigationController(withBarColor: .default)
        setLeftNavBarMenuButton()
        setupConstraints()

        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // AR experiences typically involve moving the device without
        // touch input for some time, so prevent auto screen dimming.
        UIApplication.shared.isIdleTimerDisabled = true

        // "Reset" to run the AR session for the first time.
        resetTracking()
    }

    @objc
    func startButtonPressed() {
        flowDelegate?.prepareGameStart()
    }

    func startAnimation() {
        // Start Animation
        startPlayButton.snp.updateConstraints { update in
            update.width.height.equalTo(100)
        }

        let animation: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.startPlayButton.layoutIfNeeded()
            self.startPlayButton.transform = CGAffineTransform(
                translationX: -self.view.bounds.width / 2 + 50 + self.view.safeAreaInsets.bottom,
                y: (self.view.bounds.height / 2) - 50 - self.view.safeAreaInsets.bottom
            )
        }

        UIView.animate(withDuration: 0.3, animations: animation) { [weak self] _ in
            self?.flowDelegate?.didPrepareGameStart()
        }
    }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }

        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")

        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }

    /// - Tag: ARFaceTrackingSetup
    func resetTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - Error handling
    func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }

    // MARK: - SnapKit Constraints
    func setupConstraints() {
        sceneView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        startPlayButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(250)
            make.height.equalTo(100)
        }
    }
}

extension MainViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        currentFaceAnchor = faceAnchor

        // If this is the first time with this anchor, get the controller to create content.
        // Otherwise (switching content), will change content when setting `selectedVirtualContent`.
        if node.childNodes.isEmpty, let contentNode = contentController.renderer(renderer, nodeFor: faceAnchor) {
            node.addChildNode(contentNode)
        }
    }

    /// - Tag: ARFaceGeometryUpdate
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard anchor == currentFaceAnchor,
            let contentNode = contentController.contentNode,
            contentNode.parent == node
            else { return }

        contentController.renderer(renderer, didUpdate: contentNode, for: anchor)
    }
}
