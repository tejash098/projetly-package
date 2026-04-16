// Generates an HMAC-SHA256 signature over the raw request body using the packaged secret.
// The result is Base64-encoded and sent as the x-sf-signature header.
// The backend verifies by computing HMAC(secret, request_body) on its side.
public class ProjetlySignatureUtil {

    public static String generateSignature(String payload) {
        String secret = ProjetlyConfigService.getSecret();

        Blob mac = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(payload),
            Blob.valueOf(secret)
        );

        return EncodingUtil.base64Encode(mac);
    }
}