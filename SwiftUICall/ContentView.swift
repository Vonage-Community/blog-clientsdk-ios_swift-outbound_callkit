//
//  ContentView.swift
//  SwiftUICall
//
//  Created by Abdulhakim Ajetunmobi on 30/10/2020.
//

import SwiftUI
import CallKit
import AVFoundation
import VonageClientSDKVoice

struct ContentView: View {
    @StateObject var callModel = CallModel()
    
    var body: some View {
        VStack {
            Text(callModel.status)
            
            if callModel.status == "Connected" {
                TextField("Enter a phone number", text: $callModel.number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .disabled(callModel.isCalling)
                    .padding(20)
                
                if !callModel.isCalling {
                    Button(action: { self.callModel.startCall() }) {
                        HStack(spacing: 10) {
                            Image(systemName: "phone")
                            Text("Call")
                        }
                    }
                }
                
                if self.callModel.isCalling {
                    Button(action: { self.callModel.endCall() }) {
                        HStack(spacing: 10) {
                            Image(systemName: "phone")
                            Text("End Call")
                        }.foregroundColor(Color.red)
                    }
                }
            }
        }.onAppear(perform: callModel.setup)
    }
}

final class CallModel: NSObject, ObservableObject, VGVoiceClientDelegate {
    
    @Published var status: String = ""
    @Published var isCalling: Bool = false
    private let client = VGVoiceClient()
    var number: String = ""
    
    private var callId: (vonage: String?, callkit: UUID?)
    private let callController = CXCallController()
    private let providerManager = ProviderManager()
    
    func setup() {
        initializeClient()
        requestPermissionsIfNeeded()
        loginIfNeeded()
    }
    
    func initializeClient() {
        let config = VGClientConfig(region: .US)
        client.setConfig(config)
        client.delegate = self
        providerManager.delegate = self
    }
    
    func requestPermissionsIfNeeded() {
        AVAudioApplication.requestRecordPermission { granted in
            print("Microphone permissions \(granted)")
        }
    }
    
    func updateStatus(_ text: String) {
        DispatchQueue.main.async {
            self.status = text
        }
    }
    
    func resetState() {
        DispatchQueue.main.async {
            self.callId = (nil, nil)
            self.isCalling = false
            self.number = ""
        }
    }
    
    func loginIfNeeded() {
        guard status != "Connected" else { return }
        client.createSession("JWT") { error, sessionId in
            if let error {
                self.updateStatus(error.localizedDescription)
            } else {
                self.updateStatus("Connected")
            }
        }
    }
    
    func startCall() {
        isCalling = true
        let handle = CXHandle(type: .phoneNumber, value: number)
        self.callId.callkit = UUID()
        
        let startCallAction = CXStartCallAction(call: self.callId.callkit!, handle: handle)
        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { _ in }
    }
    
    func endCall() {
        client.hangup(callId.vonage!) { error in
            if error == nil {
                if let callkitUUID = self.callId.callkit {
                    let transaction = CXTransaction(action: CXEndCallAction(call: callkitUUID))
                    self.callController.request(transaction) { _ in }
                }
            }
        }
    }
    
    func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: VGCallId, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
        if let callkitUUID = self.callId.callkit {
            providerManager.reportEndedCall(callUUID: callkitUUID)
        }
        resetState()
    }
    
    func client(_ client: VGBaseClient, didReceiveSessionErrorWith reason: VGSessionErrorReason) {
        let reasonString: String!
        
        switch reason {
        case .tokenExpired:
            reasonString = "Expired Token"
        case .pingTimeout, .transportClosed:
            reasonString = "Network Error"
        default:
            reasonString = "Unknown"
        }
        
        status = reasonString
    }
    
    func voiceClient(_ client: VGVoiceClient, didReceiveInviteForCall callId: VGCallId, from caller: String, with type: VGVoiceChannelType) {}
    func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: VGCallId, with reason: VGVoiceInviteCancelReason) {}
}

extension CallModel: ProviderManagerDelegate {
    func callReported(_ providerManager: ProviderManager, callUUID: UUID) {
        print(number)
        client.serverCall(["to": number]) { error, callId in
            if error == nil {
                providerManager.reportOutgoingCall(callUUID: callUUID)
                self.callId.vonage = callId
            } else {
                providerManager.reportFailedCall(callUUID: callUUID)
            }
        }
    }
    
    func providerReset() {
        resetState()
    }
}
