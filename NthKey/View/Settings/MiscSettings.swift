//
//  MiscSettings.swift
//  MiscSettings
//
//  Created by Fathi on 25/1/21.
//  Copyright © 2021 Purple Dunes. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import SwiftUI

struct MiscSettings: View {
    
    @EnvironmentObject var appState: AppState
    
    @State private var showMnemonic = false
    @State private var promptMainnet = false
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 20.0) {
            Text("Misc").font(.headline)
            Button(action: {
                self.showMnemonic = true
            }) {
                Text("Show mnemonic")
            }.alert(isPresented: $showMnemonic) {
                Alert(title: Text("BIP 39 mnemonic"), message: Text(self.appState.walletManager.mnemonic()), dismissButton: .default(Text("OK")))
            }
            if self.appState.walletManager.network == .testnet {
                Text("Feeling reckless?")
                if (self.appState.walletManager.hasWallet) {
                    Text("You need to wipe your existing testnet wallet first")
                }
                Button(action: {
                    self.promptMainnet = true
                }) {
                    Text("Switch to mainnet")
                }
                .disabled(self.appState.walletManager.hasWallet)
                .alert(isPresented: $promptMainnet) {
                    Alert(title: Text("Switch to mainnet?"),
                          message: Text("This app is still very new. Use only coins that you're willing to loose and write down your mnemonic. Switching back to testnet requires deleting and reinstalling the app."),
                          primaryButton: .destructive(Text("Confirm")) {
                            self.appState.walletManager.setMainnet()
                          }, secondaryButton: .cancel())
                }
            }
        }
        
    }
}

struct MiscSettings_Previews: PreviewProvider {
    static var previews: some View {
        MiscSettings()
            .environmentObject(AppState())
    }
}