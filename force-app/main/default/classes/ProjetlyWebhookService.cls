public class ProjetlyWebhookService {

    public static Boolean sendBatch(Set<Id> recordIds, String triggerType, String objectType) {
        System.debug(LoggingLevel.DEBUG, 'ProjetlyWebhookService.sendBatch: start | triggerType=' + triggerType + ' objectType=' + objectType + ' recordCount=' + (recordIds != null ? recordIds.size() : 0));

        try {
            if (recordIds == null || recordIds.isEmpty()) return true;

            // --- BUILD PAYLOAD ---
            String timestamp = generateTimestamp();
            System.debug(LoggingLevel.DEBUG, 'ProjetlyWebhookService.sendBatch: timestamp=' + timestamp);

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('org_id', UserInfo.getOrganizationId());
            payload.put('user_id', UserInfo.getUserId());
            payload.put('trigger_type', triggerType);
            payload.put('record_ids', new List<Id>(recordIds));
            payload.put('object', objectType);
            payload.put('timestamp', timestamp);

            String body = JSON.serialize(payload);
            System.debug(LoggingLevel.DEBUG, 'ProjetlyWebhookService.sendBatch: payload body=' + body);

            // --- SIGNATURE ---
            String secret = getWebhookSecret();
            System.debug(LoggingLevel.DEBUG, 'ProjetlyWebhookService.sendBatch: secret fetched successfully');
            String signature = generateSignature(timestamp, body, secret);
            String functionKey = getFunctionKey();
            System.debug(LoggingLevel.DEBUG, 'ProjetlyWebhookService.sendBatch: functionKey fetched successfully');
            System.debug(LoggingLevel.DEBUG, 'ProjetlyWebhookService.sendBatch: signature=' + signature);

            // --- HEADERS ---
            String requestId = generateRequestId();

            // --- HTTP REQUEST ---
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Projetly__Projetly_Webhook/api/salesforce/webhook');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('x-sf-request-id', requestId);
            req.setHeader('x-sf-timestamp', timestamp);
            req.setHeader('x-sf-signature', signature);
            req.setHeader('x-functions-key', functionKey);
            req.setBody(body);

            System.debug(LoggingLevel.DEBUG, 'ProjetlyWebhookService.sendBatch: sending HTTP request to webhook endpoint');

            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();
            System.debug(LoggingLevel.DEBUG, 'ProjetlyWebhookService.sendBatch: response statusCode=' + statusCode + ' body=' + res.getBody());

            return (statusCode >= 200 && statusCode < 300);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ProjetlyWebhookService error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            return false;
        }
    }

    @TestVisible
    private static String getWebhookSecret() {
        System.debug(LoggingLevel.DEBUG, 'DEBUG: Fetching webhook secret');
        List<Projetly_Config__mdt> configs = [
            SELECT Webhook_Secret__c
            FROM Projetly__Projetly_Config__mdt
            LIMIT 1
        ];
        if (!configs.isEmpty() && configs[0].Webhook_Secret__c != null) {
            return configs[0].Webhook_Secret__c;
        }
        return '';
    }

    @TestVisible
    private static String getFunctionKey() {
        System.debug(LoggingLevel.DEBUG, 'DEBUG: Fetching function key');
        List<Projetly_Config__mdt> configs = [
            SELECT Function_Key__c
            FROM Projetly__Projetly_Config__mdt
            LIMIT 1
        ];
        if (!configs.isEmpty() && configs[0].Function_Key__c != null) {
            return configs[0].Function_Key__c;
        }
        return '';
    }

    @TestVisible
    private static String generateSignature(String timestamp, String body, String secret) {
        String rawPayload = timestamp + '.' + body;
        System.debug(LoggingLevel.DEBUG, 'ProjetlyWebhookService.generateSignature: rawPayload=' + rawPayload);

        Blob keyBlob  = Blob.valueOf(secret);
        Blob dataBlob = Blob.valueOf(rawPayload);
        Blob hmac     = Crypto.generateMac('HmacSHA256', dataBlob, keyBlob);
        String signature = 'sha256=' + EncodingUtil.convertToHex(hmac);

        System.debug(LoggingLevel.DEBUG, 'ProjetlyWebhookService.generateSignature: signature=' + signature);
        return signature;
    }

    // --- HELPER METHODS ---
    private static String generateRequestId() {
        // Combine timestamp and random integer, then take first 16 chars
        Long timestamp = DateTime.now().getTime();
        Integer randomPart = Math.abs(Crypto.getRandomInteger());

        String combined = String.valueOf(timestamp) + String.valueOf(randomPart);

        if (combined.length() >= 16) {
            return combined.substring(0, 16);
        } else {
            // Manual padding (Apex way)
            Integer remaining = 16 - combined.length();
            String padding = '';

            for (Integer i = 0; i < remaining; i++) {
                padding += '0';
            }

            return combined + padding;
        }
    }

    private static String generateTimestamp() {
        // Epoch milliseconds — matches the format the backend uses for body_timestamp comparison
        return String.valueOf(DateTime.now().getTime());
    }
}