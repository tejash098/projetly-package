global class ProjetlyPostInstallHandler implements InstallHandler {

    global void onInstall(InstallContext context) {
        Id installingUserId = context.installerId();

        verifyNamedCredential();
        assignPermissionSet(installingUserId);
    }

    private static void verifyNamedCredential() {
        try {
            List<NamedCredential> creds = [
                SELECT Id, DeveloperName
                FROM NamedCredential
                WHERE DeveloperName = 'Projetly_Webhook'
                LIMIT 1
            ];
            if (creds.isEmpty()) {
                System.debug(LoggingLevel.WARN,
                    'ProjetlyPostInstall: Named Credential "Projetly_Webhook" not found. ' +
                    'Webhook callouts will fail until it is configured.');
            } else {
                System.debug(LoggingLevel.INFO,
                    'ProjetlyPostInstall: Named Credential "Projetly_Webhook" verified.');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'ProjetlyPostInstall: Named Credential check failed - ' + e.getMessage());
        }
    }

    private static void assignPermissionSet(Id installingUserId) {
        try {
            List<PermissionSet> psList = [
                SELECT Id
                FROM PermissionSet
                WHERE Name = 'Projetly_User'
                LIMIT 1
            ];

            if (psList.isEmpty()) {
                System.debug(LoggingLevel.WARN,
                    'ProjetlyPostInstall: Permission Set "Projetly_User" not found. ' +
                    'Named Credential access will not be granted automatically.');
                return;
            }

            Id psId = psList[0].Id;

            List<PermissionSetAssignment> existing = [
                SELECT Id
                FROM PermissionSetAssignment
                WHERE AssigneeId = :installingUserId
                AND PermissionSetId = :psId
                LIMIT 1
            ];

            if (existing.isEmpty()) {
                insert new PermissionSetAssignment(
                    AssigneeId = installingUserId,
                    PermissionSetId = psId
                );
                System.debug(LoggingLevel.INFO,
                    'ProjetlyPostInstall: Permission Set "Projetly_User" assigned to installer (' +
                    installingUserId + ').');
            } else {
                System.debug(LoggingLevel.INFO,
                    'ProjetlyPostInstall: Permission Set "Projetly_User" already assigned to installer.');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'ProjetlyPostInstall: Failed to assign Permission Set - ' + e.getMessage());
        }
    }
}
