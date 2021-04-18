//
//  NetworkingService.swift
//  PayU Demo
//
//  Copyright © 2019 PayU. All rights reserved.
//

import Foundation
import PayU_SDK_Lite
import Alamofire

class NetworkingService {
    
    
    private var accessToken : String? = nil
    
    private func authorize(completion : @escaping () -> Void) {
        let parameters = [
            "client_id": Constants.posId,
            "client_secret" : Constants.ClientSecret
        ]
        
        AF.request(Urls.Auth,method: .get ,parameters: parameters).responseDecodable(of: AuthResponse.self) {[weak self] (response) -> Void in
            if let response = response.value {
                self?.accessToken = response.access_token
                print("Response Auth \(response)")
                completion()
            }
        }
    }
    
    
    func fetchPaymentMethods(completion : @escaping ([PUPaymentMethod]) -> Void)  {
        
        
        authorize {
            
            let headers: HTTPHeaders = [
                "Authorization": "Bearer \(self.accessToken ?? "")",
                "Accept": "application/json"
            ]
            
            AF.request(Urls.PaymentMethods,method: .get ,headers: headers).responseDecodable(of: PaymentMethodsResponse.self) { (response) -> Void in
                
                
                var paymentMethods: [PUPaymentMethod] = []
                
                let responsePayByLinks = response.value!.payByLinks
                var payByLinks = [PUPayByLink]()
                responsePayByLinks.forEach { (item) in
                        let item = PUPayByLink(name: item.name, value: item.value, brandImageProvider: PUBrandImageProvider(brandImageURL: URL(string: item.brandImageUrl)!), status: .enabled)
                        payByLinks.append(item)
                    
                }
                
                paymentMethods.append(contentsOf: payByLinks)
                completion(paymentMethods)
            }
        }
    }
    
    // MARK: - Create Order Generic
    func createOrder(request : CreateOrderRequest,completionHandler : @escaping (OrderCreateResponse) -> Void) {
      
        
        authorize {
            let redirector = Redirector(behavior:.doNotFollow)
            
            let jsonData = try! JSONEncoder().encode(request)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            print(jsonString)

           let headers: HTTPHeaders = [
            "Authorization": "Bearer \(self.accessToken ?? "")",
                "Accept": "application/json",
                "Content-Type":"application/json"
            ]
            
           
            AF.request(Urls.CreateOrder,method: .post ,parameters: request,encoder: JSONParameterEncoder.default ,headers: headers)
                .redirect(using: redirector)
                .responseDecodable(of: OrderCreateResponse.self) { (createOrderResponse) -> Void in
                    if let response = createOrderResponse.value {
                        completionHandler(response)
                    }
            }
        }
       
    }
}
