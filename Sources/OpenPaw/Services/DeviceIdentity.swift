import Foundation
import CryptoKit

struct DeviceIdentity {
    let privateKey: Curve25519.Signing.PrivateKey
    let publicKey: Curve25519.Signing.PublicKey
    let publicKeyBase64URL: String
    let deviceID: String

    private static let keyDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".openpaw", isDirectory: true)
    private static let keyFile = keyDir.appendingPathComponent("device-identity.key")

    static func loadOrCreate() -> DeviceIdentity {
        let key: Curve25519.Signing.PrivateKey

        if let data = try? Data(contentsOf: keyFile),
           let stored = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) {
            key = stored
        } else {
            key = Curve25519.Signing.PrivateKey()
            try? FileManager.default.createDirectory(at: keyDir, withIntermediateDirectories: true)
            try? key.rawRepresentation.write(to: keyFile, options: .atomic)
        }

        let pub = key.publicKey
        let pubRaw = pub.rawRepresentation
        let pubB64 = pubRaw.base64URLEncodedString()
        let devID = SHA256.hash(data: pubRaw)
            .compactMap { String(format: "%02x", $0) }
            .joined()

        return DeviceIdentity(
            privateKey: key,
            publicKey: pub,
            publicKeyBase64URL: pubB64,
            deviceID: devID
        )
    }

    func sign(payload: String) throws -> String {
        let data = Data(payload.utf8)
        let signature = try privateKey.signature(for: data)
        return signature.base64URLEncodedString()
    }

    func buildSignedDevice(
        nonce: String,
        token: String,
        clientID: String,
        clientMode: String,
        role: String,
        scopes: [String]
    ) throws -> (device: [String: Any], signedAt: Int) {
        let signedAt = Int(Date().timeIntervalSince1970 * 1000)
        let scopesStr = scopes.joined(separator: ",")

        // v2 payload: v2|deviceId|clientId|clientMode|role|scopes|signedAtMs|token|nonce
        let payload = [
            "v2",
            deviceID,
            clientID,
            clientMode,
            role,
            scopesStr,
            String(signedAt),
            token,
            nonce
        ].joined(separator: "|")

        let signature = try sign(payload: payload)

        let device: [String: Any] = [
            "id": deviceID,
            "publicKey": publicKeyBase64URL,
            "signature": signature,
            "signedAt": signedAt,
            "nonce": nonce
        ]
        return (device, signedAt)
    }

}

// MARK: - Base64URL

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
