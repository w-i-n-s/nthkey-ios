//
//  SubscriptionManager.swift
//  SubscriptionManager
//
//  Created by Sergey Vinogradov on 03.05.2021.
//  Copyright © 2021 Purple Dunes. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import Foundation
import Combine
import StoreKit

final class SubscriptionManager: NSObject, ObservableObject {
    @Published private(set) var hasSubscription: Bool = false
    @Published private(set) var products: [SKProduct] = []

    // Used for direct user notifications about purchase flow
    let purchasePublisher = PassthroughSubject<(String, Bool), Never>()

    static var canMakePayments: Bool {
        SKPaymentQueue.canMakePayments()
    }

    private var totalRestoredPurchases = 0

    private let identifiers: [String]

    init(identifiers: [String]) {
        self.identifiers = identifiers
        super.init()

        checkPurchaseStatus()
    }

    // MARK: - Public

    func startObserving() {
        SKPaymentQueue.default().add(self)
    }

    func stopObserving() {
        SKPaymentQueue.default().remove(self)
    }

    func prepareData() {
        getProducts()
    }

    func purchase(product: SKProduct) -> Bool {
        guard SubscriptionManager.canMakePayments else { return false }

        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)

        return true
    }

    func restorePurchases() {
        totalRestoredPurchases = 0
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    // MARK: - Private

    private func getProducts() {
        let request = SKProductsRequest(productIdentifiers: Set(identifiers))
        request.delegate = self
        request.start()
    }

    private func checkPurchaseStatus() {
        guard let date = UserDefaults.subscriptionDate else { return }
        hasSubscription = Date() < date
    }

    static private func expirationDateFromResponse(jsonResponse: NSDictionary) -> NSDate? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss VV"

        guard let receiptInfo: NSArray = jsonResponse["latest_receipt_info"] as? NSArray,
              let lastReceipt = receiptInfo.lastObject as? NSDictionary,
              let dateString = lastReceipt["expires_date"] as? String,
              let expirationDate = formatter.date(from: dateString) as NSDate? else { return nil }

        return expirationDate
    }

    /// Allow to have raw estimation of subscription vithout validation
    private func checkExpirationDateFromPayment(_ payment: SKPayment) {
        let productId = payment.productIdentifier
        for item in ["month": 30, "year": 365] {
            guard productId.contains(item.key) else { continue }
            let date = Date(timeIntervalSinceNow: TimeInterval(60*60*24*item.value))
            UserDefaults.subscriptionDate = date
            checkPurchaseStatus()
        }
    }
}

extension SubscriptionManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        #if DEBUG
        let badProducts = response.invalidProductIdentifiers
        if !badProducts.isEmpty {
            print("Next products are not on the store anymore:\(badProducts.description)")
        }
        #endif

        products = response.products
    }
}

extension SubscriptionManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        transactions.forEach { (transaction) in
            switch transaction.transactionState {
            case .purchased:
                purchasePublisher.send(("Purchased ",true))
                checkExpirationDateFromPayment(transaction.payment)
            case .restored:
                totalRestoredPurchases += 1
                purchasePublisher.send(("Restored ",true))

                checkExpirationDateFromPayment(transaction.payment)
            case .failed:
                if let error = transaction.error as? SKError {
                    purchasePublisher.send(("Payment Error \(error.code) ",false))
                }
            case .deferred:
                purchasePublisher.send(("Payment Deferred ",false))
            case .purchasing:
                purchasePublisher.send(("Payment in Process ",false))
            default:
                break
            }

            guard !(transaction.transactionState == .purchasing || transaction.transactionState == .deferred) else {
                return
            }
            
            queue.finishTransaction(transaction)
        }
    }

    // Sent when all transactions from the user's purchase history have successfully been added back to the queue.
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        guard totalRestoredPurchases != 0 else {
            purchasePublisher.send(("IAP: No purchases to restore!",true))
            return
        }

        purchasePublisher.send(("IAP: Purchases successfull restored!",true))
    }

    // Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        guard let error = error as? SKError else { return }
        let reason = error.code != .paymentCancelled ? " Restore" : ""
        purchasePublisher.send(("IAP\(reason) Error: " + error.localizedDescription, false))
    }

    // TODO: Possible should implement for any transactions which will be revoked
    // func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction])
}

extension SubscriptionManager: SKRequestDelegate {
    func request(_ request: SKRequest, didFailWithError error: Error) {
        purchasePublisher.send(("Purchase request failed ",true))
    }
}

#if DEBUG
extension SubscriptionManager {
    static var mock: SubscriptionManager = SubscriptionManager(identifiers: ["com.nthkey.monthly", "com.nthkey.annual"])

    static var alreadyBought: SubscriptionManager {
        let result = SubscriptionManager(identifiers: ["com.test.subscription"])
        // Here we can use #if targetEnvironment(simulator) and set date accordingly or just set flag directly
        result.hasSubscription = true
        return result
    }
}
#endif