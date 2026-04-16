@isTest
private class ProjetlyConfigTest {

    // Verifies that the packaged Projetly_Webhook_Config__mdt.Default record is present and the secret field is populated.
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
        String payload = '{"test":"data"}';

        Test.startTest();

        String signature = ProjetlySignatureUtil.generateSignature(payload);

        Test.stopTest();

        System.assertNotEquals(null, signature, 'Signature must not be null');
        System.assert(signature.length() > 0, 'Signature must not be blank');
    }
}
