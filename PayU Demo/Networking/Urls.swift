//
//  Urls.swift
//  PayU Demo
//
//  Created by macbook on 18/04/2021.
//  Copyright © 2021 Objectivity. All rights reserved.
//

import Foundation

struct Urls {
    static let BaseUrl = "https://secure.snd.payu.com"
    static let Auth = BaseUrl + "/pl/standard/user/oauth/authorize?grant_type=client_credentials"
    static let PaymentMethods = BaseUrl + "/api/v2_1/paymethods/"
    static let CreateOrder = BaseUrl + "/api/v2_1/orders";
}
