// Generates an HMAC-SHA256 request signature using the packaged secret.
// The message format is: requestId.timestamp.payload
// The result is Base64-encoded and sent as the x-sf-signature header.
public class ProjetlySignatureUtil {

    public static String generateSignature(String payload, String timestamp, String requestId) {
        String secret = ProjetlyConfigService.getSecret();

        // Canonical message: requestId.timestamp.payload
        String message = requestId + '.' + timestamp + '.' + payload;

        Blob key  = Blob.valueOf(secret);
        Blob data = Blob.valueOf(message);

        Blob mac = Crypto.generateMac('HmacSHA256', data, key);

        return EncodingUtil.base64Encode(mac);
    }
}
