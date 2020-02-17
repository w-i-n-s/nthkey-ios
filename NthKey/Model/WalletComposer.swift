//
//  WalletComposer.swift
//  WalletComposer
//
//  Created by Sjors Provoost on 16/02/2020.
//  Copyright © 2020 Purple Dunes. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import Foundation
import LibWally
import OutputDescriptors

public struct WalletComposer : Codable {
    
    public var announcements: [String:SignerAnnouncement]
    public var descriptor_receive: String?
    public var descriptor_change: String?
    public var policy: String?
    public var policy_template: String?
    public var sub_policies: [String: String]?

    public struct SignerAnnouncement: Codable {
        var name: String
        var can_decompile_miniscript: Bool?
        var sub_policy: String?
        
        init(name: String, us: Bool, sub_policy: String?) {
            self.name = name
            self.sub_policy = sub_policy
            if (us) {
                self.can_decompile_miniscript = false
            }
        }

    }

    public init?(us: Signer, signers: [Signer], threshold: Int? = nil) {
        self.announcements = signers.reduce(into: [:]) { announcements, signer in
            announcements[signer.fingerprint.hexString] = SignerAnnouncement(name: us == signer ? "NthKey" : "", us: us == signer, sub_policy: "pk(\(signer.fingerprint.hexString))")
        }
        if let threshold = threshold {
            self.policy = "thresh(\(threshold),\(signers.map { signer in "pk(\( signer.fingerprint.hexString ))" }.joined(separator:",") ))"
            self.policy_template = "thresh(\(threshold),\(signers.map { signer in "sub_policies(\( signer.fingerprint.hexString ))" }.joined(separator:",") ))"
            let network = signers[0].hdKey.network
            self.descriptor_receive = self.descriptor(signers: signers, threshold: threshold, internalKey: false, network: network)
            self.descriptor_change = self.descriptor(signers: signers, threshold: threshold, internalKey: true, network: network)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        announcements = try container.decode([String:SignerAnnouncement].self, forKey: .announcements)

        for announcement in announcements {
            let fingerprint = announcement.key
            if fingerprint.count != 8 {
                throw DecodingError.dataCorruptedError(
                    forKey:.announcements,
                    in: container,
                    debugDescription: """
                    Expected "\(fingerprint)" to have 8 characters
                    """
                )
            }

            guard let value = Data(fingerprint) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .announcements,
                    in: container,
                    debugDescription: """
                    Failed to convert an instance of \(Data.self) from "\(fingerprint)"
                    """
                )
            }

            if value.hexString != fingerprint {
                  throw DecodingError.dataCorruptedError(
                      forKey:.announcements,
                      in: container,
                      debugDescription: """
                      "\(fingerprint)" is not hex
                      """
                  )
            }

        }
        
    }
    
    func descriptor(signers: [Signer], threshold: Int, internalKey: Bool, network: Network) -> String {
        let keys = signers.map { signer in
            let cointype: String
            switch (network) {
            case .mainnet:
                cointype = "0h"
            case .testnet:
                cointype = "1h"
            }
            let origin = "\(signer.fingerprint.hexString)/48h/\(cointype)/0h/2h"
            return "[\(origin)]\(signer.hdKey.xpub)/\(internalKey ? "1" : "0")/*"
        }.joined(separator: ",")
        let descriptor = "wsh(sortedmulti(\(threshold),\(keys)))"
        let desc = try! OutputDescriptor(descriptor)
        return "\(descriptor)#\(desc.checksum)"
    }
}