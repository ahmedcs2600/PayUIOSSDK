//
//  DetailViewController.swift
//  PayU Demo
//
//  Copyright © 2019 PayU. All rights reserved.
//

import UIKit
import PayU_SDK_Lite

class CheckoutViewController: UIViewController {

    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var totalPrice: UILabel!
    @IBOutlet weak var productStackView: UIStackView!
    @IBOutlet weak var payButton: UIButton!
    @IBOutlet weak var clearCacheButton: UIButton! // Removes all payment methods. Removes selected payment method as well. Brings widget to initial state.
    
    var detailItem: Item?

    var paymentWidgetService: PUPaymentWidgetService!
    var cvvAuthorizationHandler: PUCvvAuthorizationHandler!
    var applePayHandler: PUApplePayHandler!
    var paymentWidgetVisualStyle: PUVisualStyle!
    var networkingService = NetworkingService()
    
    @IBAction func clearCacheButtonTouched(_ sender: UIButton) {
        paymentWidgetService.clearCache()
    }
    
    @IBAction func payButtonTouched(_ sender: UIButton) {
        payAction()
    }
    
    func configureView() {
        guard let item = detailItem else {
            return
        }
        
        productNameLabel.text = item.name
        productNameLabel.font = AppBranding.font!
        
        let price = String(format: "%@ %.2f", "€", Double(item.price/100))
        totalPrice.text = price
        totalPrice.font = AppBranding.font!
        
        payButton.backgroundColor = AppBranding.primaryColor
        payButton.tintColor = AppBranding.secondaryColor
        payButton.titleLabel?.font = AppBranding.font!
        
        clearCacheButton.tintColor = AppBranding.primaryColor
        clearCacheButton.titleLabel?.font = AppBranding.font!
        
        // Configure payment components
        paymentWidgetVisualStyle = PUVisualStyle()
        paymentWidgetVisualStyle.accentColor = AppBranding.primaryColor
        
        configurePaymentWidgetService()
        configurePaymentWidget()
        cvvAuthorizationHandler = PUCvvAuthorizationHandler(visualStyle: paymentWidgetVisualStyle, uIparent: self, environment: .sandbox)
    }

    
    func configurePaymentWidgetService() {
        
        let config = PUPaymentMethodsConfiguration()
        config.environment = .sandbox
        config.posID = "301948"
        config.isBlikEnabled = true
        
        let paymentMethods = networkingService.fetchPaymentMethods()
        config.cardTokens = paymentMethods.filter({ $0 is PUCardToken }) as! [PUCardToken]
        config.blikTokens = paymentMethods.filter({ $0 is PUBlikToken }) as! [PUBlikToken]
        config.payByLinks = paymentMethods.filter({ $0 is PUPayByLink }) as! [PUPayByLink]
        config.pexTokens = paymentMethods.filter({ $0 is PUPexToken }) as! [PUPexToken]

        self.paymentWidgetService = PUPaymentWidgetService(configuration: config)
        self.paymentWidgetService.delegate = self
    }
    
    func configurePaymentWidget() {
        
        // HINT: To see all available customization fields, check the documentation (chapter: Core. UI Visual style)
        let paymentWidget = self.paymentWidgetService.getWidgetWith(paymentWidgetVisualStyle)
        paymentWidget.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(paymentWidget)
        NSLayoutConstraint.activate([
            paymentWidget.topAnchor.constraint(equalTo: productStackView.bottomAnchor),
            paymentWidget.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            paymentWidget.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:))))
    }
    
    @objc
    func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
    private func navigate(to viewController: UIViewController) {
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .currentContext
        present(navigationController, animated: true)
    }
    
    private func displayShoppingConfirmation() {
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "shoppingConfirmation", sender: self)
        }
    }
    
    private func displayError(_ error: String?) {
        let alertController = UIAlertController(title: "Error", message: error, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
        }
        alertController.addAction(alertAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func payAction() {
        // 1. Ensure user has selected any payment method
        guard let selectedPaymentMethod = paymentWidgetService.selectedPaymentMethod else {
            return
        }
        
        // 2. Check which method is selected
        switch selectedPaymentMethod {
            
            
        case is PUBlikCode: // HINT: PUBlikCode is equivalent for PayU Android SKD's BlikGeneric
            
            // 2.1.1 Ensure there is a valid code in textfield.
            if paymentWidgetService.isBlikAuthorizationCodeRequired,
                let code = paymentWidgetService.blikAuthorizationCode {
                
                // 2.1.2 Ask your networking service to create order request (OCR) with given data
                networkingService.createOrder(withBlikCode: code) { [weak self] in
                    // 2.1.3 Payment completed, present success or failure
                    self?.displayShoppingConfirmation()
                }
            } else {
                // 2.1.1.1 Blik code is invalid, show error
                displayError("Invalid blik code")
            }
            break
            
        case is PUBlikToken:
            
            // 2.2.0 - If user tapped "Enter new BLIK code", isBlikAuthorizationCodeRequired is set. Handle this like PUBlikCode.
            if paymentWidgetService.isBlikAuthorizationCodeRequired {
                
                // 2.2.0.1 - same as 2.1.1
                if let code = paymentWidgetService.blikAuthorizationCode {
                    
                    // 2.2.0.2 - same as 2.1.2
                    networkingService.createOrder(withBlikCode: code) { [weak self] in
                        // 2.2.0.3 - same as 2.1.3
                        self?.displayShoppingConfirmation()
                    }
                    break
                } else {
                    // 2.2.0.1.1 - same as 2.1.1.1
                    displayError("Invalid blik code")
                    break
                }
            }
            
            // 2.2.1 Ask your networking service to create order request (OCR) with given data
            networkingService.createOrder(forBlikTokenPaymentMethod: selectedPaymentMethod as! PUBlikToken) { [weak self] blikAlternatives in
                
                // 2.2.2 If blik alternatives exists, present them in PUBlikAlternativesViewController.
                //       Don't forget to set the delegate.
                if let blikAlternatives = blikAlternatives {
                    let chooseBlikController = PUBlikAlternativesViewController(itemsList: blikAlternatives, visualStyle: self?.paymentWidgetVisualStyle ?? PUVisualStyle.default())
                    chooseBlikController.delegate = self
                    self?.navigate(to: chooseBlikController)
                } else {
                    // 2.2.3 Payment completed, present success or failure
                    displayShoppingConfirmation()
                }
            }
            break
            
        // HINT: Pay by link and PEX are similar web payment methods
        case is PUPayByLink, is PUPexToken:
            
            // 2.3.1 Ask your networking service to create order request (OCR) with given data
            networkingService.crateOrder(withWebPaymentMethod: selectedPaymentMethod) { [weak self] authorizationRequest in
                
                // 2.3.2 Prepare PUWebAuthorizationViewController object reference
                var authorizationController: PUWebAuthorizationViewController?
                
                // 2.3.3 Create a proper PUWebAuthorizationViewController object
                if let authorizationRequest = authorizationRequest as? PUPayByLinkAuthorizationRequest {
                    authorizationController = PUWebAuthorizationBuilder().viewController(for: authorizationRequest, visualStyle: self?.paymentWidgetVisualStyle ?? PUVisualStyle.default())
                } else if let authorizationRequest  = authorizationRequest as? PUPexAuthorizationRequest {
                    authorizationController = PUWebAuthorizationBuilder().viewController(for: authorizationRequest, visualStyle: self?.paymentWidgetVisualStyle ?? PUVisualStyle.default())
                }
                
                // 2.3.4 Present authorizationController - user will continue payment in webview.
                //       Don't forget to set the delegate.
                authorizationController?.authorizationDelegate = self;
                if let authorizationController = authorizationController {
                    self?.navigate(to: authorizationController)
                }
            }
            break
            
        case is PUCardToken:
            // 2.4.1 Ask your networking service to create order request (OCR) with given data
            networkingService.crateOrder(withCardTokenPaymentMethod: selectedPaymentMethod as! PUCardToken) { [weak self] authorizationRequest, refReqId in
                
                // 2.4.2 If there is a CVV authorization challange, authorize it using refReqId and cvvAuthorizationHandler
                if let refReqId = refReqId {
                    self?.cvvAuthorizationHandler.authorizeRefReqId(refReqId) { [weak self] result in
                        // 2.4.2.1 Payment completed, present success or failure
                        if result == PUCvvAuthorizationResult.statusSuccess {
                            self?.displayShoppingConfirmation()
                        } else {
                            self?.displayError("cvv authorization failed")
                        }
                    }
                    return
                }
                
                // 2.4.3 If there is a 3ds authorization challange, prepare and present PUWebAuthorizationViewController
                if let authorizationRequest = authorizationRequest {
                    let authorizationController = PUWebAuthorizationBuilder().viewController(for: authorizationRequest, visualStyle: self?.paymentWidgetVisualStyle ?? PUVisualStyle.default())
                    authorizationController.authorizationDelegate = self;
                    self?.navigate(to: authorizationController)
                    return
                }
                
                // 2.4.4 If there is no challenge, payment is completed, present success or failure
                displayShoppingConfirmation()
            }
            break
            
        case is PUApplePay:
            // 2.5.1 Create PUApplePayTransaction object with your data
            let applePayTransaction = PUApplePayTransaction(merchantIdentifier: "merchant.payu.applepayresearch.131313",
                                                            currencyCode: PUCurrencyCode.PLN,
                                                            countryCode: PUCountryCode.PL,
                                                            contactEmailAddress: "email_address@toUser.pl",
                                                            paymentItemDescription: "Item description",
                                                            amount: NSDecimalNumber(string: "55.5"))
            
            // 2.5.2 Create PUApplePayHandler object and assign a delegate
            applePayHandler = PUApplePayHandler()
            self.applePayHandler.delegate = self
            
            // 2.5.3 Authorize transaction with applePayHandler.
            applePayHandler.authorizeTransaction(applePayTransaction, withUIparent: self)
            
            // 2.5.4 In delegate method, ask your networking service to create order request (OCR) with given data
            
        default:
            break
        }
    }

}

extension CheckoutViewController: PUPaymentWidgetServiceDelegate {
    func paymentWidgetServiceDidDeselectPaymentMethod(_ paymentWidgetService: PUPaymentWidgetService) {
        // update UI if needed (e.g. disable PAY button)
    }
    
    func paymentWidgetService(_ paymentWidgetService: PUPaymentWidgetService, didSelect cardToken: PUCardToken) {
        // update UI if needed (e.g. enable PAY button)
    }
    
    func paymentWidgetService(_ paymentWidgetService: PUPaymentWidgetService, didSelect payByLink: PUPayByLink) {
        // update UI if needed (e.g. enable PAY button)
    }
    
    func paymentWidgetService(_ paymentWidgetService: PUPaymentWidgetService, didSelect applePay: PUApplePay) {
        // update UI if needed (e.g. enable PAY button)
    }
    
    func paymentWidgetService(_ paymentWidgetService: PUPaymentWidgetService, didSelect blikCode: PUBlikCode) {
        // update UI if needed (e.g. enable PAY button)
    }
    
    func paymentWidgetService(_ paymentWidgetService: PUPaymentWidgetService, didSelect blikToken: PUBlikToken) {
        // update UI if needed (e.g. enable PAY button)
    }
    
    func paymentWidgetService(_ paymentWidgetService: PUPaymentWidgetService, didSelect pexToken: PUPexToken) {
        // update UI if needed (e.g. enable PAY button)
    }
    
    func paymentWidgetService(_ paymentWidgetService: PUPaymentWidgetService, didDelete cardToken: PUCardToken) {
        // update UI if needed
    }
    
    func paymentWidgetService(_ paymentWidgetService: PUPaymentWidgetService, didDelete pexToken: PUPexToken) {
        // update UI if needed
    }
}

extension CheckoutViewController: PUBlikAlternativesViewControllerDelegate {
    func blikAlternativesViewController(_ blikAlternativesViewController: PUBlikAlternativesViewController, didSelect blikAlternative: PUBlikAlternative) {
        // 2.2.2.1 Ask your networking service to continue payment with selected blik alternative
        networkingService.continuePayment(withBlikAlternative: blikAlternative) { [weak self] in
            // 2.2.2.2 Payment completed, present success or failure
            self?.displayShoppingConfirmation()
        }
    }
}

extension CheckoutViewController: PUAuthorizationDelegate {
    
    func authorizationRequest(_ request: PUAuthorizationRequest, didFinishWith result: PUAuthorizationResult, userInfo: [AnyHashable : Any]? = nil) {
        switch result {
        case .success:
            // 2.3.5 Payment completed, present success
            handleAuthorizationResultSuccess()
            break
        case .failure:
            // 2.3.5 Payment completed with failure, present failure
            guard let userInfo = userInfo,
                let error = userInfo[PUAuthorizationResultErrorUserInfoKey] as? Error
                else { return }
            handleAuthorizationResultFailure(error)
            break
        case .continueCvv:
            // 2.4.3.1 If there is a CVV authorization challange, authorize it using refReqId and cvvAuthorizationHandler (note: cvv authorization challenge can appear as a part of 3ds authorization as well)
            guard let request = request as? PU3dsAuthorizationRequest,
                let userInfo = userInfo,
                let refReqId = userInfo[PUAuthorizationResultRefReqIdUserInfoKey] as? String else { return }
            handleAuthorizationResultContinueCVV(request, refReqId: refReqId)
            break
        default:
            break
        }
    }

    private func handleAuthorizationResultSuccess() {
        displayShoppingConfirmation()
    }
    private func handleAuthorizationResultFailure(_ error: Error) {
        displayError("authorization failed")
    }
    private func handleAuthorizationResultContinueCVV(_ requst: PU3dsAuthorizationRequest, refReqId: String) {
        self.cvvAuthorizationHandler.authorizeRefReqId(refReqId) { [weak self] result in
            // 2.4.3.2 show error or continue depending on the result
            switch result {
            case .statusSuccess:
                self?.displayShoppingConfirmation()
            case .statusFailure:
                self?.displayError("cvv authorization failed")
            case .statusCanceled:
                self?.displayError("cvv authorization cancelled")
            }
        }
    }
}

extension CheckoutViewController: PUApplePayHandlerDelegate {
    func paymentTransactionCanceled(byUser transaction: PUApplePayTransaction!) {
        // handle cancel action
        displayError("Payment canceled by user")
    }

    func paymentTransaction(_ transaction: PUApplePayTransaction!, result: String!) {
        // 2.5.4 Ask your networking service to create order request (OCR) with given data
        networkingService.crateOrder { [weak self] in
            // 2.5.5 Payment completed, display succes or failure
            self?.displayShoppingConfirmation()
        }
    }
}

