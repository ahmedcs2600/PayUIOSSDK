//
//  PaymentMethodsResponse.swift
//  PayU Demo
//
//  Created by macbook on 18/04/2021.
//  Copyright © 2021 Objectivity. All rights reserved.
//

import Foundation
struct PaymentMethodsResponse : Decodable {
    //let cardTokens : [CardTokens]
    //let pexTokens : [PexTokens]
    let payByLinks : [PayByLinks]
    
    
    enum PaymentMethodsResponse: String, CodingKey {
       case payByLinks
     }
}

/*struct BlikTokens : Decodable {
    let value : String
    let type : String
    let brandImageUrl : String
    
    
    enum CodingKeys: String, CodingKey {
        case value
        case type
        case brandImageUrl
        case producer
      }
}*/

struct CardTokens : Decodable {
    let cardExpirationYear : String
    let cardExpirationMonth : String
    let cardNumberMasked : String
    let cardScheme : String
    let value : String
    let brandImageUrl : String
    let preferred : String
    let status : String
}


struct PexTokens : Decodable {
    let accountNumber : String
    let payType : String
    let value : String
    let name : String
    let brandImageUrl : String
    let preferred : String
    let status : String
}

struct PayByLinks : Decodable {
    let value : String
    let brandImageUrl : String
    let name : String
    let status : String
    //let minAmount : Int
    //let maxAmount : Int
    
    
    enum CodingKeys: String, CodingKey {
        case value
        case brandImageUrl
        case name
        case status
        //case minAmount
        //case maxAmount
      }
}
