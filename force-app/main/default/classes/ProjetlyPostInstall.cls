global class ProjetlyPostInstall implements InstallHandler {

    global void onInstall(InstallContext context) {

        // Get Permission Set
        PermissionSet ps = [
            SELECT Id FROM PermissionSet
            WHERE Name = 'Projetly_User'
            LIMIT 1
        ];

        // Assign to installing user
        insert new PermissionSetAssignment(
            AssigneeId = UserInfo.getUserId(),
            PermissionSetId = ps.Id
        );

        // notify backend
        sendInstallEvent();
    }

    private static void sendInstallEvent() {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Projetly_Backend/package-install');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('event', 'package_installed');
            payload.put('org_id', UserInfo.getOrganizationId());
            payload.put('user_id', UserInfo.getUserId());

            req.setBody(JSON.serialize(payload));
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('Install event sent: ' + res.getBody());
        } catch (Exception e) {
            System.debug('Error sending install event: ' + e.getMessage());
        }
    }
}