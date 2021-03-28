//
//  ContentViewModel.swift
//  ContentViewModel
//
//  Created by Sergey Vinogradov on 11.03.2021.
//  Copyright © 2021 Purple Dunes. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import Foundation


enum ContentViewTab: Hashable {
    case addresses
    case sign
    case settings
}

class ContentViewModel: ObservableObject {
    @Published var selectedTab: ContentViewTab = .addresses

    // TODO: remove constant model after avoiding constant redraw
    let addressesModel: AddressesViewModel
    let settingsModel: SettingsViewModel

    private let dataManager: DataManager

    init(dataManager: DataManager) {
        self.dataManager = dataManager

        addressesModel = AddressesViewModel(dataManager: dataManager)
        settingsModel = SettingsViewModel(dataManager: dataManager)
    }
}