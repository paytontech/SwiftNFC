import SwiftUI
import CoreNFC

@available(iOS 13.0, *)
public class NFCReader: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    
    public var startAlert = "Hold your iPhone near the tag."
    public var endAlert = ""
    public var msg: Data = "Scan to read or Edit here to write...".data(using: .utf8)!
    public var raw = "Raw Data available after scan."

    public var session: NFCNDEFReaderSession?
    public var onMessage: ((Data) -> Void)?
    public func read(onMessage: @escaping (Data) -> Void) {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("Error")
            return
        }
        self.onMessage = onMessage
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = self.startAlert
        session?.begin()
    }
    
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async {
//            self.msg = messages.map {
//                $0.records.map {
//                    String(decoding: $0.payload, as: UTF8.self)
//                }.joined(separator: "\n")
//            }.joined(separator: " ")
            for message in messages {
                for payload in message.records {
                    if payload.typeNameFormat == .media {
                        self.msg = payload.payload
                    }
                }
            }
            if self.onMessage != nil {
                self.onMessage!(self.msg)
            }
            self.raw = messages.map {
                $0.records.map {
                    "\($0.typeNameFormat) \(String(decoding:$0.type, as: UTF8.self)) \(String(decoding:$0.identifier, as: UTF8.self)) \(String(decoding: $0.payload, as: UTF8.self))"
                }.joined(separator: "\n")
            }.joined(separator: " ")


            session.alertMessage = self.endAlert != "" ? self.endAlert : "Read \(messages.count) NDEF Messages, and \(messages[0].records.count) Records."
        }
    }
    
    public func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    }
    
    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("Session did invalidate with error: \(error)")
        self.session = nil
    }
}

public class NFCWriter: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    
    public var startAlert = "Hold your iPhone near the tag."
    public var endAlert = ""
    public var msg: Data = Data()
    public var type = "FUCK FUCK FUCK FUCK"
    
    public var session: NFCNDEFReaderSession?
    
    public func write() {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("Error")
            return
        }
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = self.startAlert
        session?.begin()
    }
    
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("found NDEF")
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                guard error == nil else {
                    session.alertMessage = "Unable to query the status of tag."
                    session.invalidate()
                    return
                }

                switch ndefStatus {
                case .notSupported:
                    session.alertMessage = "Tag is not NDEF compliant."
                    session.invalidate()
                case .readOnly:
                    session.alertMessage = "Read only tag detected."
                    session.invalidate()
                case .readWrite:
                    let payload: NFCNDEFPayload?
                    if self.type == "T" {
                        payload = NFCNDEFPayload.init(
                            format: .nfcWellKnown,
                            type: Data("\(self.type)".utf8),
                            identifier: Data(),
                            payload: self.msg
                        )
                    } else {
                        payload = NFCNDEFPayload(format: .media, type: "application".data(using: .utf8)!, identifier: Data(), payload: self.msg)
                    }
                    let message = NFCNDEFMessage(records: [payload].compactMap({ $0 }))
                    tag.writeNDEF(message, completionHandler: { (error: Error?) in
                        if nil != error {
                            print(error)
                            if let errorCode = (error! as NSError).userInfo[NFCISO15693TagResponseErrorKey] as? NSNumber {
                                print(errorCode)
                            }
                            session.alertMessage = "failed :("
                        } else {
                            session.alertMessage = self.endAlert != "" ? self.endAlert : "Write \(self.msg) to tag successful."
                        }
                        session.invalidate()
                    })
                @unknown default:
                    session.alertMessage = "Unknown tag status."
                    session.invalidate()
                }
            })
        })
    }
    
    public func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("Session did invalidate with error: \(error)")
        self.session = nil
    }
}
