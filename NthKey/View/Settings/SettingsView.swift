//
//  SettingsView.swift
//  SettingsView
//
//  Created by Sjors Provoost on 12/12/2019.
//  Copyright © 2019 Purple Dunes. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import SwiftUI
import CodeScanner

struct SettingsView : View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20.0) {
                SettingsSectionView("Tutorial") {
                    HStack {
                        Link("Open tutorial", destination: URL(string:  "https://nthkey.com/tutorial")!)
                    }
                }

                if model.hasSeed {
                    SettingsSectionView("Announce") {
                        AnnounceView(model: model.announceModel,
                                     activeSheet: $model.activeSheet)
                    }

                    SettingsSectionView("Import wallet") {
                        ImportWalletView(model: model.importWalletModel,
                                         activeSheet: $model.activeSheet)
                    }

                    SettingsSectionView("Wallets") {
                        WalletListView(model: model.walletListModel)
                    }

                    SettingsSectionView("Wallet details") {
                        CodeSignersView(model: model.codeSignersModel)
                    }

                    SettingsSectionView("Misc") {
                        MiscSettings()
                    }
                } else {
                    NoSeedView(hasSeed: $model.hasSeed)
                }
            }
            .padding(10)
        }
        .sheet(item: $model.activeSheet) { value in
            switch value {
                case .scanner:
                    CodeScannerView(codeTypes: [.qr], completion: model.handleScan)
                case .subscription:
                    SubscriptionView(model: model.subsViewModel,
                                     closeBlock: { model.activeSheet = nil })
            }
        }
        .alert(item: $model.scanQRError) { error in
            Alert(title: Text("Scan wallet QR error"),
                  message: Text(error.errorDescription ?? "Unknown error"),
                  dismissButton: .cancel())
        }
    }
}

#if DEBUG

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsView(model: SettingsViewModel.mock)

            NavigationView {
                SettingsView(model: SettingsViewModel.notSeeded)
            }
            .colorScheme(.dark)
        }
    }
}
#endif
