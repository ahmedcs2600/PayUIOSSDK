//
//  OrderCreateResponse.swift
//  PayU Demo
//
//  Created by macbook on 18/04/2021.
//  Copyright © 2021 Objectivity. All rights reserved.
//

import Foundation

// MARK: - OrderCreateResponse
struct OrderCreateResponse : Codable {
    let extOrderId, orderId, redirectUri, error : String?
    let status : Status?
    
    
    init(extOrderId : String, orderId : String, redirectUri : String,status : Status?,error:String) {
        self.extOrderId = extOrderId
        self.orderId = orderId
        self.redirectUri = redirectUri
        self.status = status
        self.error = error
        
    }
    
    enum CodingKeys: String, CodingKey {
        case extOrderId, orderId, redirectUri,status,error
    }
}


// MARK: - Status
struct Status: Codable {
    
    static let Success = "SUCCESS"
    static let WarningContinue3DS = "WARNING_CONTINUE_3DS"
    static let WarningContinueCVV = "WARNING_CONTINUE_CVV"
    
    let statusCode : String
    let code : String?
    let codeLiteral : String?
    let statusDesc : String?
    
    init(statusCode : String, code: String?, codeLiteral: String?,statusDesc: String?) {
        self.statusCode = statusCode
        self.code = code
        self.codeLiteral = codeLiteral
        self.statusDesc = statusDesc
    }
}
