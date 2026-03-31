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
    }
}