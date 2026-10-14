# Apple Wallet passes for seasonal tokens

After a customer pays for a seasonal token, the confirmation screen and the token page
show **Add to Apple Wallet**. The pass carries the token number, service, date, time,
"arrive by" time and a QR code of the reference (the desk can scan it). It becomes
relevant on the lock screen near the token time, shows at the salon's location, and
expires a day after the token.

The button stays hidden until the salon's Apple certificate is configured.

## One-time setup (Apple Developer account required)

1. In developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers**, create a
   **Pass Type ID**, e.g. `pass.om.maisonbeauty.tokens`.
2. Create a **Pass Type ID certificate** for it (upload a CSR), download the `.cer`, and export
   the certificate + private key as PEM:
   ```
   openssl x509 -inform der -in pass.cer -out signerCert.pem
   openssl pkcs12 -in Certificates.p12 -nocerts -out signerKey.pem
   ```
3. Download Apple's **WWDR G4** intermediate certificate and convert it to PEM.
4. In Vercel → `glowbook-api` → Environment Variables (Production), add:

   | Variable | Value |
   |---|---|
   | `APPLE_WALLET_PASS_TYPE_ID` | the Pass Type ID |
   | `APPLE_WALLET_TEAM_ID` | your 10-character Team ID |
   | `APPLE_WALLET_CERT` | contents of `signerCert.pem` |
   | `APPLE_WALLET_KEY` | contents of `signerKey.pem` |
   | `APPLE_WALLET_KEY_PASSPHRASE` | only if the key has one |
   | `APPLE_WALLET_WWDR` | contents of the WWDR PEM |

   Multi-line values can be pasted as-is or with `\n` escapes.
5. Redeploy the API. The button appears for paid tokens.

Code: `backend/src/server/seasonal/wallet.ts`, route `GET /api/public/tokens/:id/wallet?token=…&lang=en|ar`.
