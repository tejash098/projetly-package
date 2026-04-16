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

            // --- HTTP REQUEST ---
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Projetly_Webhook/webhook');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
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
}