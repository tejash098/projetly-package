public class ProjetlyWebhookService {

    public static Boolean sendBatch(Set<Id> recordIds, String triggerType, String objectType) {

        try {
            if (recordIds == null || recordIds.isEmpty()) return true;

            // --- BUILD PAYLOAD ---
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('org_id', UserInfo.getOrganizationId());
            payload.put('user_id', UserInfo.getUserId());
            payload.put('trigger_type', triggerType);
            payload.put('record_ids', new List<Id>(recordIds));
            payload.put('object', objectType);

            String body = JSON.serialize(payload);

            // --- HEADERS ---
            String timestamp = generateTimestamp();
            String requestId = generateRequestId();
            String signature = ProjetlySignatureUtil.generateSignature(body, timestamp, requestId);

            // --- HTTP REQUEST ---
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Projetly_Webhook/webhook');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('x-sf-request-id', requestId);
            req.setHeader('x-sf-timestamp', timestamp);
            req.setHeader('x-sf-signature', signature);
            req.setBody(body);

            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();
            return (statusCode >= 200 && statusCode < 300);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ProjetlyWebhookService error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            return false;
        }
    }

    // --- HELPER METHOD ---
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
        // ISO 8601 UTC format
        return DateTime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
}