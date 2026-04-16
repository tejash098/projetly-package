@isTest
private class ProjetlyConfigTest {

    // Verifies that the packaged Default MDT record is present and the secret field is populated.
    @isTest
    static void testGetSecret() {
        Test.startTest();

        String secret = ProjetlyConfigService.getSecret();

        Test.stopTest();

        System.assertNotEquals(null, secret, 'Secret must not be null');
        System.assert(secret.length() > 0, 'Secret must not be blank');
    }

    // Verifies that generateSignature returns a non-null Base64-encoded HMAC value.
    @isTest
    static void testGenerateSignature() {
        String payload   = '{"test":"data"}';
        String timestamp = '2026-01-01T00:00:00Z';
        String requestId = '1234567890123456';

        Test.startTest();

        String signature = ProjetlySignatureUtil.generateSignature(payload, timestamp, requestId);

        Test.stopTest();

        System.assertNotEquals(null, signature, 'Signature must not be null');
        System.assert(signature.length() > 0, 'Signature must not be blank');
    }
}
