//
//  ProviderManager.swift
//  SwiftUICall
//
//  Created by Abdulhakim Ajetunmobi on 27/09/2023.
//

import CallKit
import Foundation
import VonageClientSDKVoice

protocol ProviderManagerDelegate: AnyObject {
    func callReported(_ providerManager: ProviderManager, callUUID: UUID)
    func providerReset()
}

final class ProviderManager: NSObject {

    private static var providerConfiguration: CXProviderConfiguration = {
        let providerConfiguration = CXProviderConfiguration()
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic, .phoneNumber]
        return providerConfiguration
    }()
    
    private let provider = CXProvider(configuration: ProviderManager.providerConfiguration)
    weak var delegate: ProviderManagerDelegate?
    
    override init() {
        super.init()
        provider.setDelegate(self, queue: nil)
    }
    
    public func reportOutgoingCall(callUUID: UUID) {
        provider.reportOutgoingCall(with: callUUID, connectedAt: .now)
    }
    
    public func reportFailedCall(callUUID: UUID) {
        provider.reportCall(with: callUUID, endedAt: .now, reason: .failed)
    }
    
    public func reportEndedCall(callUUID: UUID) {
        provider.reportCall(with: callUUID, endedAt: .now, reason: .remoteEnded)
    }
}

extension ProviderManager: CXProviderDelegate {
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: .now)
        delegate?.callReported(self, callUUID: action.callUUID)
        action.fulfill()
    }
    
    func providerDidReset(_ provider: CXProvider) {
        delegate?.providerReset()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        VGVoiceClient.enableAudio(audioSession)
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        VGVoiceClient.disableAudio(audioSession)
    }
}
