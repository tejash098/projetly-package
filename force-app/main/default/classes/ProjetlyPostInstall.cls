global class ProjetlyPostInstall implements InstallHandler {

    global void onInstall(InstallContext context) {
        try {
            // Get Permission Set
            List<PermissionSet> psList = [
                SELECT Id FROM PermissionSet
                WHERE Name = 'Projetly_User'
                LIMIT 1
            ];

            if (psList.isEmpty()) {
                System.debug('Projetly_User Permission Set not found. Skipping assignment.');
                return;
            }

            Id psId = psList[0].Id;
            Id userId = UserInfo.getUserId();

            // Check if already assigned (handles re-install / upgrade)
            List<PermissionSetAssignment> existing = [
                SELECT Id FROM PermissionSetAssignment
                WHERE AssigneeId = :userId AND PermissionSetId = :psId
                LIMIT 1
            ];

            if (existing.isEmpty()) {
                insert new PermissionSetAssignment(
                    AssigneeId = userId,
                    PermissionSetId = psId
                );
            }

            // Fire callout asynchronously to avoid DML-before-callout error
            sendInstallEventAsync();

        } catch (Exception e) {
            System.debug('PostInstall error: ' + e.getMessage());
        }
    }

    @future(callout=true)
    private static void sendInstallEventAsync() {
        try {
            String requestId = generateRequestId();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Projetly_Webhook/package-install');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('x-sf-request-id', requestId);

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('event', 'package_installed');
            payload.put('org_id', UserInfo.getOrganizationId());
            payload.put('user_id', UserInfo.getUserId());

            req.setBody(JSON.serialize(payload));
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                System.debug('Install event failed. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
            } else {
                System.debug('Install event sent successfully: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error sending install event: ' + e.getMessage());
        }
    }

    private static String generateRequestId() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 32);
    }
}
