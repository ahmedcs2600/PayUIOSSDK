//
//  DetailViewController.swift
//  PayU Demo
//
//  Copyright © 2019 PayU. All rights reserved.
//

import UIKit
import PayU_SDK_Lite
import JGProgressHUD

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
    public var networkingService = NetworkingService()
    
    @IBAction func clearCacheButtonTouched(_ sender: UIButton) {
        paymentWidgetService.clearCache()
    }
    
    @IBAction func payButtonTouched(_ sender: UIButton) {
        // 1. Ensure user has selected any payment method
        guard let selectedPaymentMethod = paymentWidgetService.selectedPaymentMethod else {
            return
        }
        
        showLoader()
        
        switch selectedPaymentMethod {
        case is PUBlikCode: // HINT: PUBlikCode is equivalent for PayU Android SKD's BlikGeneric
            didTapPUBlikCode(selectedPaymentMethod: selectedPaymentMethod)
            break
        case is PUBlikToken:
            // 2.2.0 - If user tapped "Enter new BLIK code", isBlikAuthorizationCodeRequired is set. Handle this like PUBlikCode.
            didTapBlikToken(selectedPaymentMethod: selectedPaymentMethod)
            break
        case is PUPayByLink, is PUPexToken:
            payByLinkPexToken(selectedPaymentMethod: selectedPaymentMethod)
            break
        case is PUCardToken:
            didTapPUCardToken(selectedPaymentMethod: selectedPaymentMethod)
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
        default:
            break
        }
    }
    
    private func handlePblPayment(order: OrderCreateResponse) {
        if (!isPaymentCompleted(order : order)) {
            let authorizationRequest = PUPayByLinkAuthorizationRequest(orderId: order.orderId!,
                                                                       extOrderId: "",
                                                                       redirectUri: URL(string: order.redirectUri!)!,
                                                                       continueUrl: URL(string: "")!)
            
            let authorizationController = PUWebAuthorizationBuilder().viewController(for: authorizationRequest, visualStyle: paymentWidgetVisualStyle ?? PUVisualStyle.default())
            authorizationController.authorizationDelegate = self;
            navigate(to: authorizationController)
        }
    }
    
    private func handlePexPayment(order : OrderCreateResponse) {
        if (!isPaymentCompleted(order: order)) {
            
            
            let authorizationRequest = PUPexAuthorizationRequest(orderId: order.orderId!,
                                                                 extOrderId: "ext_orderId",
                                                                 redirectUri: URL(string: order.redirectUri!)!,
                                                                 continueUrl: URL(string: "")!)
            
            let authorizationController = PUWebAuthorizationBuilder().viewController(for: authorizationRequest, visualStyle: paymentWidgetVisualStyle ?? PUVisualStyle.default())
            
            authorizationController.authorizationDelegate = self;
            navigate(to: authorizationController)
            
        }
    }
    
    
    private func handleOtherPayment(order: OrderCreateResponse) {
        if (!isPaymentCompleted(order : order)) {
            let authorizationRequest = PU3dsAuthorizationRequest(orderId: order.orderId!, extOrderId: "extOrderId", redirectUri: URL(string: order.redirectUri!)!)
            let authorizationController = PUWebAuthorizationBuilder().viewController(for: authorizationRequest, visualStyle: paymentWidgetVisualStyle ?? PUVisualStyle.default())
            authorizationController.authorizationDelegate = self;
            navigate(to: authorizationController)
        }
    }
    
    
    private func handleOrderCreateResponse(response : OrderCreateResponse,selectedPaymentMethod: PUPaymentMethod) {
        if(isOCRValid(orderCreateResponse: response)){
                switch selectedPaymentMethod {
                case is PUPayByLink:
                    handlePblPayment(order: response)
                    break
                case is PUPexToken:
                    handlePexPayment(order: response)
                    break
                case is PUCardToken:
                    handleCardPayment(order: response)
                    break
                default:
                    // PUBlikCode,PUBlikToken
                    handleOtherPayment(order: response)
                    break
                }
        }
    }
    
    private func handleCardPayment(order: OrderCreateResponse) {
        switch order.status?.statusCode {
        case Status.Success:
            didPaymentDone()
            break
        case Status.WarningContinue3DS:
            let authorizationRequest = PU3dsAuthorizationRequest(orderId: order.orderId!, extOrderId: "extOrderId", redirectUri: URL(string: order.redirectUri!)!)
            let authorizationController = PUWebAuthorizationBuilder().viewController(for: authorizationRequest, visualStyle: paymentWidgetVisualStyle ?? PUVisualStyle.default())
            authorizationController.authorizationDelegate = self;
            navigate(to: authorizationController)
            break
        case Status.WarningContinueCVV:
            cvvAuthorizationHandler.authorizeRefReqId(order.redirectUri!) { [weak self] result in
                if result == PUCvvAuthorizationResult.statusSuccess {
                    self?.didPaymentDone()
                } else {
                    self?.displayError("cvv authorization failed")
                }
            }
            break
        default:
            didPaymentError()
        }
    }
    
    func didTapPUCardToken(selectedPaymentMethod: PUPaymentMethod) {
        
        let request = getOrderRequest(paymentMethod: selectedPaymentMethod, authorizationCode: nil, paymentValue: (selectedPaymentMethod as! PUCardToken).value)
        
        networkingService.createOrder(request : request){ [weak self] response in
            self?.handleOrderCreateResponse(response: response, selectedPaymentMethod: selectedPaymentMethod)
        }
    }
    
    private func payByLinkPexToken(selectedPaymentMethod: PUPaymentMethod) {
        var value : String
        if(selectedPaymentMethod is PUPayByLink){
            value = (selectedPaymentMethod as! PUPayByLink).value
        }else{
            value = (selectedPaymentMethod as! PUPexToken).value
        }
       let request = getOrderRequest(paymentMethod: selectedPaymentMethod, authorizationCode: nil, paymentValue: value)
       
        networkingService.createOrder(request: request) { [weak self] response in
            self?.handleOrderCreateResponse(response: response, selectedPaymentMethod: selectedPaymentMethod)
        }
    }
    
    private func didTapBlikToken(selectedPaymentMethod: PUPaymentMethod) {
        // 2.2.0 - If user tapped "Enter new BLIK code", isBlikAuthorizationCodeRequired is set. Handle this like PUBlikCode.
        if paymentWidgetService.isBlikAuthorizationCodeRequired {
        
            if let code = paymentWidgetService.blikAuthorizationCode {
                let request = getOrderRequest(paymentMethod: selectedPaymentMethod, authorizationCode: code, paymentValue: (selectedPaymentMethod as! PUBlikToken).value)
                networkingService.createOrder(request : request) { [weak self] response in
                    self?.handleOrderCreateResponse(response: response, selectedPaymentMethod: selectedPaymentMethod)
                }
            } else {
                // 2.2.0.1.1 - same as 2.1.1.1
                displayError("Invalid blik code")
            }
        }else{
            let request = getOrderRequest(paymentMethod: selectedPaymentMethod, authorizationCode: nil, paymentValue: (selectedPaymentMethod as! PUBlikToken).value)
            
            networkingService.createOrder(request : request) { [weak self] response in
                self?.handleOrderCreateResponse(response: response, selectedPaymentMethod: selectedPaymentMethod)
            }
        }
    }
    
    private func didTapPUBlikCode(selectedPaymentMethod: PUPaymentMethod) {
        // 2.1.1 Ensure there is a valid code in textfield.
        if paymentWidgetService.isBlikAuthorizationCodeRequired,
           let code = paymentWidgetService.blikAuthorizationCode {
            
            let request = getOrderRequest(paymentMethod: selectedPaymentMethod, authorizationCode: code, paymentValue: (selectedPaymentMethod as! PUBlikCode).value)
            
            networkingService.createOrder(request : request) { [weak self] response in
                self?.handleOrderCreateResponse(response: response, selectedPaymentMethod: selectedPaymentMethod)
            }
        } else {
            displayError(NSLocalizedString("BlikCodeNotEntered", comment: ""))
        }
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
        cvvAuthorizationHandler = PUCvvAuthorizationHandler(visualStyle: paymentWidgetVisualStyle, uIparent: self, environment: .sandbox)
    }

    
    func configurePaymentWidgetService() {
        
        let config = PUPaymentMethodsConfiguration()
        config.environment = .sandbox
        config.posID = Constants.posId
        config.isBlikEnabled = true
        
        
        networkingService.fetchPaymentMethods(completion: { [weak self] methods in
            config.cardTokens = methods.filter({ $0 is PUCardToken }) as! [PUCardToken]
            config.blikTokens = methods.filter({ $0 is PUBlikToken }) as! [PUBlikToken]
            config.payByLinks = methods.filter({ $0 is PUPayByLink }) as! [PUPayByLink]
            config.pexTokens = methods.filter({ $0 is PUPexToken }) as! [PUPexToken]
            
            self?.paymentWidgetService = PUPaymentWidgetService(configuration: config)
            self?.paymentWidgetService.delegate = self
            
            self?.configurePaymentWidget()
                
            
        })
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
    
    
    let hud = JGProgressHUD()
    
    private func showLoader() {
        hud.textLabel.text = "Loading"
        hud.show(in: self.view)
    }
    
    private func hideLoader() {
        hud.dismiss()
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
//        networkingService.continuePayment(withBlikAlternative: blikAlternative) { [weak self] in
//            // 2.2.2.2 Payment completed, present success or failure
//            self?.displayShoppingConfirmation()
//        }
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
        let selectedPaymentMethod = paymentWidgetService.selectedPaymentMethod!
        let value = (selectedPaymentMethod as! PUApplePay).value
        let request = getOrderRequest(paymentMethod: selectedPaymentMethod, authorizationCode: result, paymentValue: value)
        
        networkingService.createOrder(request: request) { [weak self] response in
            self?.handleOrderCreateResponse(response: response, selectedPaymentMethod: selectedPaymentMethod)
        }
    }
}

// Mark :- Extras
extension CheckoutViewController {
    public func isOCRValid(orderCreateResponse : OrderCreateResponse?) -> Bool{
        let successStatusList = [Status.Success,Status.WarningContinue3DS,Status.WarningContinueCVV]
        
        if(orderCreateResponse == nil || !successStatusList.contains(orderCreateResponse?.status?.statusCode ?? "")){
            return false
        }
        return orderCreateResponse?.error != "invalid token"
    }
    
    
    func didPaymentDone() {
        hideLoader()
        print("Shooping Done")
    }
    
    
    func didPaymentCancel() {
        hideLoader()
        print("Payment Cancel")
    }
    
    
    func didPaymentError() {
        hideLoader()
        print("Payment Error")
    }
    
    public func isPaymentCompleted(order: OrderCreateResponse) -> Bool {
        if (order.status?.statusCode == Status.Success && order.redirectUri?.isEmpty ?? true) {
              didPaymentDone()
              return true
          }
          return false
      }
    
    
    public func getOrderRequest(
        paymentMethod: PUPaymentMethod,
        authorizationCode : String?,
        
        paymentValue : String) -> CreateOrderRequest {
        
        let buyer = Buyer(email: "abc@a.com", phone: nil, firstName: "Test", lastName: nil, language: "pl")
        
        var products = [Product]()
        products.append(Product(name: "Product Name", unitPrice: "1000", quantity: "1"))
        
        let request = CreateOrderRequest(notifyURL: "", continueUrl: "",customerIP: "127.0.0.1", merchantPosID: Constants.posId, createOrderRequestDescription: "Details", currencyCode: "PL", totalAmount: "1000", buyer: buyer, products: products,payMethods: getPayMethods(paymentMethod: paymentMethod, authorizationCode: authorizationCode,paymentValue: paymentValue), extOrderId: "ext_orderId")
        
        return request
    }
    
    
    private func getPayMethods(paymentMethod: PUPaymentMethod, authorizationCode : String?, paymentValue : String) -> PayMethods {
        var paymentType : String
        switch paymentMethod {
        case is PUBlikCode, is PUPayByLink:
            paymentType = "PBL"
            break
        case is PUCardToken, is PUPexToken:
            paymentType = "CARD_TOKEN"
            break
        case is PUBlikToken:
            paymentType = "BLIK_TOKEN"
            break
        default:
            paymentType = "BLIK_TOKEN"
        }
        
        let value =  paymentMethod is PUBlikCode ? "blik" : paymentValue
    
        return PayMethods(payMethod: PayMethod(type: paymentType, value: value, authorizationCode: authorizationCode, blikData: nil))
    
    }
}

