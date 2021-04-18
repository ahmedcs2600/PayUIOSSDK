//
//  CreateOrderRequest.swift
//  PayU Demo
//
//  Created by macbook on 18/04/2021.
//  Copyright © 2021 Objectivity. All rights reserved.
//

import Foundation
// MARK: - CreateOrderRequest
struct CreateOrderRequest: Codable {
    let notifyURL: String?
    let continueUrl : String
    let customerIP, merchantPosID, createOrderRequestDescription, currencyCode, extOrderId: String
    let totalAmount: String
    let buyer: Buyer
    let products: [Product]
    let payMethods : PayMethods?
    
    init(notifyURL: String?,continueUrl : String,customerIP : String, merchantPosID : String, createOrderRequestDescription : String, currencyCode: String,totalAmount : String,buyer : Buyer, products : [Product], payMethods : PayMethods?, extOrderId : String) {
        self.notifyURL = notifyURL
        self.continueUrl = continueUrl
        self.customerIP = customerIP
        self.merchantPosID = merchantPosID
        self.createOrderRequestDescription = createOrderRequestDescription
        self.currencyCode = currencyCode
        self.totalAmount = totalAmount
        self.buyer = buyer
        self.products = products
        self.payMethods = payMethods
        self.extOrderId = extOrderId
    }
    
    enum CodingKeys: String, CodingKey {
        case notifyURL = "notifyUrl"
        case customerIP = "customerIp"
        case merchantPosID = "merchantPosId"
        case createOrderRequestDescription = "description"
        case currencyCode, totalAmount, buyer, products,continueUrl, payMethods, extOrderId
    }
}

// MARK: - Buyer
struct Buyer: Codable {
    let email : String
    let phone, firstName, lastName: String?
    let language: String?
    
    init(email : String, phone : String?, firstName : String?, lastName : String?,language : String?) {
        self.email = email
        self.phone = phone
        self.firstName = firstName
        self.lastName = lastName
        self.language = language
    }
}


// MARK: - PayMethods
struct PayMethods: Codable {
    let payMethod : PayMethod
    
    init(payMethod : PayMethod) {
        self.payMethod = payMethod
    }
    
    enum CodingKeys: String, CodingKey {
        case payMethod
    }
}

// MARK: - PayMethod
struct PayMethod: Codable {
    let type, value : String
    let authorizationCode : String?
    let blikData : BlikData?
    
    init(type : String, value : String , authorizationCode : String?,blikData : BlikData?) {
        self.type = type
        self.value = value
        self.authorizationCode = authorizationCode
        self.blikData = blikData
    }
    
    enum CodingKeys: String, CodingKey {
        case type, value, authorizationCode, blikData
    }
}


// MARK: - BlikData
struct BlikData: Codable {
    let register, appKey : String
    
    init(register : String, appKey : String) {
        self.register = register
        self.appKey = appKey
    }
}

// MARK: - Product
struct Product: Codable {
    let name, unitPrice, quantity: String
    
    init(name : String, unitPrice : String , quantity : String) {
        self.name = name
        self.unitPrice = unitPrice
        self.quantity = quantity
    }
}
