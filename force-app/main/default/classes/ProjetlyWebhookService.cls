public class ProjetlyWebhookService {

    public static Boolean sendBatch(Set<Id> recordIds, String triggerType, String objectType) {

        try {
            if (recordIds == null || recordIds.isEmpty()) return true;

            // --- BUILD PAYLOAD ---
            String timestamp = String.valueOf(DateTime.now().getTime());

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('org_id', UserInfo.getOrganizationId());
            payload.put('user_id', UserInfo.getUserId());
            payload.put('trigger_type', triggerType);
            payload.put('record_ids', recordIds);
            payload.put('object', objectType);
            payload.put('timestamp', timestamp);

            String body = JSON.serialize(payload);

            // --- SECRET ---
            List<Projetly_Config__c> configs = [
                SELECT Secret__c
                FROM Projetly_Config__c
                WHERE Active__c = true
                LIMIT 1
            ];

            if (configs.isEmpty() || configs[0].Secret__c == null) {
                throw new IllegalArgumentException('No active Projetly configuration found.');
            }

            String secret = configs[0].Secret__c;

            // --- SIGNATURE ---
            String signature = generateSignature(body, secret);

            // --- REQUEST ID ---
            String requestId = generateRequestId();

            // --- HTTP REQUEST ---
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Projetly_Webhook/webhook');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('x-sf-signature', signature);
            req.setHeader('x-sf-request-id', requestId);
            req.setHeader('x-sf-timestamp', timestamp);
            req.setBody(body);

            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();

            // success
            if (statusCode >= 200 && statusCode < 300) {
                return true;
            }

            return false;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ProjetlyWebhookService error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            return false;
        }
    }

    // --- HMAC SIGNATURE ---
    private static String generateSignature(String payload, String secret) {
        Blob key = Blob.valueOf(secret);
        Blob data = Blob.valueOf(payload);
        Blob mac = Crypto.generateMac('HmacSHA256', data, key);
        return EncodingUtil.base64Encode(mac);
    }

    // --- REQUEST ID ---
    private static String generateRequestId() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 16);
    }
}