global class ProjetlyPostInstall implements InstallHandler {

    global void onInstall(InstallContext context) {
        try {
            // --- Optional: Assign Permission Set (non-blocking) ---
            // Query both names to handle managed package namespace prefix
            List<PermissionSet> psList = [
                SELECT Id, Name FROM PermissionSet
                WHERE Name IN ('Projetly_User', 'Projetly__Projetly_User')
            ];

            // Prefer unnamespaced name; fall back to managed package name
            PermissionSet matchedPs = null;
            for (PermissionSet ps : psList) {
                if (ps.Name == 'Projetly_User') {
                    matchedPs = ps;
                    break;
                }
            }
            if (matchedPs == null && !psList.isEmpty()) {
                matchedPs = psList[0];
            }

            if (matchedPs == null) {
                System.debug(LoggingLevel.WARN, 'PostInstall: Projetly_User Permission Set not found. Skipping assignment.');
            } else {
                Id psId = matchedPs.Id;
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
            }

            // Always fire callout — pass context values before entering async scope
            sendInstallEventAsync(UserInfo.getOrganizationId(), UserInfo.getUserId());

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'PostInstall error: ' + e.getMessage());
        }
    }

    @future(callout=true)
    private static void sendInstallEventAsync(String orgId, String userId) {
        try {
            String requestId = generateRequestId();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://subarticulate-nonseasonally-cleora.ngrok-free.dev/api/salesforce/package-install');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('x-sf-request-id', requestId);

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('event', 'package_installed');
            payload.put('org_id', orgId);
            payload.put('user_id', userId);

            req.setBody(JSON.serialize(payload));
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                System.debug(LoggingLevel.WARN, 'PostInstall: Install event failed. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
            } else {
                System.debug(LoggingLevel.INFO, 'PostInstall: Install event sent successfully: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'PostInstall: Error sending install event: ' + e.getMessage());
        }
    }

    private static String generateRequestId() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 32);
    }
}
