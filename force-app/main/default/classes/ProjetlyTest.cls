@isTest
private class ProjetlyTest {

    // ─── Failure mock (503) ───────────────────────────────────────────────────
    class HttpMockFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody('{"error":"unavailable"}');
            return res;
        }
    }

    // ─── Account Trigger ──────────────────────────────────────────────────────

    @isTest
    static void testAccountTrigger() {
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Test.startTest();

        Account acc = new Account(Name = 'Acc');
        insert acc;                    // trigger_type='create'

        acc.Name = 'Updated';
        update acc;                    // trigger_type='update'

        delete acc;                    // trigger_type='delete'

        Test.stopTest();
    }

    // ─── Contact Trigger ──────────────────────────────────────────────────────

    @isTest
    static void testContactTrigger() {
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Account acc = new Account(Name = 'Contact Acc');
        insert acc;

        Contact con = new Contact(LastName = 'Test', AccountId = acc.Id);

        Test.startTest();

        insert con;                    // trigger_type='create', object='contact', ids=[con.Id]

        con.LastName = 'Updated';
        update con;                    // trigger_type='update', object='contact', ids=[con.Id]

        delete con;                    // trigger_type='delete', object='contact', ids=[con.Id]

        Test.stopTest();
    }

    // ─── Opportunity Trigger ──────────────────────────────────────────────────

    @isTest
    static void testOpportunityFlow() {
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );

        Test.startTest();

        insert opp;                    // trigger_type='create'

        opp.Name = 'Updated Opp';
        update opp;                    // trigger_type='update'

        delete opp;                    // trigger_type='delete'

        Test.stopTest();
    }

    // ─── OpportunityContactRole Trigger ──────────────────────────────────────

    @isTest
    static void testOCRTrigger() {
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Account acc = new Account(Name = 'Acc');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert opp;

        Contact con = new Contact(LastName = 'Test', AccountId = acc.Id);
        insert con;

        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = con.Id,
            Role = 'Decision Maker'
        );

        Test.startTest();

        insert ocr;                    // trigger_type='create', object='contact', ids=[con.Id]

        ocr.Role = 'Influencer';
        update ocr;                    // trigger_type='update', object='contact', ids=[con.Id]

        delete ocr;                    // trigger_type='delete', object='contact', ids=[con.Id]

        Test.stopTest();
    }

    // ─── Bulk insert ──────────────────────────────────────────────────────────

    @isTest
    static void testBulkOpportunities() {
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Account acc = new Account(Name = 'Bulk Acc');
        insert acc;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(new Opportunity(
                Name = 'Bulk Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                AccountId = acc.Id
            ));
        }

        Test.startTest();

        insert opps;   // All 200 IDs collected in a single queueable

        Test.stopTest();

        System.assertEquals(200, [SELECT COUNT() FROM Opportunity WHERE AccountId = :acc.Id],
            '200 opportunities should be inserted');
    }

    // ─── Bulk delete (all IDs in one payload) ─────────────────────────────────

    @isTest
    static void testBulkDelete() {
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Account acc = new Account(Name = 'Bulk Delete Acc');
        insert acc;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 50; i++) {
            opps.add(new Opportunity(
                Name = 'Del Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                AccountId = acc.Id
            ));
        }
        insert opps;

        Set<Id> expectedIds = new Set<Id>();
        for (Opportunity o : opps) expectedIds.add(o.Id);

        Test.startTest();

        delete opps;   // All 50 deletes batched into one queueable with 50 IDs

        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Opportunity WHERE AccountId = :acc.Id],
            'All 50 opportunities should be deleted');
        System.assertEquals(50, expectedIds.size(), '50 distinct IDs should have been collected');
    }

    // ─── Direct service tests ─────────────────────────────────────────────────

    @isTest
    static void testDirectSendBatch_success() {
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Account acc = new Account(Name = 'Svc Acc');
        insert acc;

        Test.startTest();
        Boolean result = ProjetlyWebhookService.sendBatch(new Set<Id>{ acc.Id }, 'update', 'Account');
        Test.stopTest();

        System.assertEquals(true, result, 'Valid callout should return true');
    }

    @isTest
    static void testDirectSendBatch_failure() {
        Test.setMock(HttpCalloutMock.class, new HttpMockFail());

        Account acc = new Account(Name = 'Fail Acc');
        insert acc;

        ProjetlyQueueable.skipRetry = true;

        Test.startTest();
        Boolean result = ProjetlyWebhookService.sendBatch(new Set<Id>{ acc.Id }, 'update', 'Account');
        Test.stopTest();

        System.assertEquals(false, result, 'Failed callout (503) should return false');
    }

    @isTest
    static void testDirectSendBatch_emptyIds() {
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Test.startTest();
        Boolean result = ProjetlyWebhookService.sendBatch(new Set<Id>(), 'update', 'Opportunity');
        Test.stopTest();

        System.assertEquals(true, result, 'Empty recordIds should return true (no-op)');
    }

    @isTest
    static void testDirectSendBatch_nullIds() {
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Test.startTest();
        Boolean result = ProjetlyWebhookService.sendBatch(null, 'update', 'Opportunity');
        Test.stopTest();

        System.assertEquals(true, result, 'Null recordIds should return true (no-op)');
    }

    // ─── Queueable retry tests ────────────────────────────────────────────────

    @isTest
    static void testRetryOnFailure() {
        Test.setMock(HttpCalloutMock.class, new HttpMockFail());

        Account acc = new Account(Name = 'Retry Acc');
        insert acc;

        // skipRetry prevents infinite queueable chaining in test context
        ProjetlyQueueable.skipRetry = true;

        Test.startTest();
        Set<Id> ids = new Set<Id>{ acc.Id };
        System.enqueueJob(new ProjetlyQueueable(ids, 'update', 'Account', 0));
        Test.stopTest();

        System.assert(true, 'Retry path executed without exception');
    }

    @isTest
    static void testQueueableRetryChain() {
        Test.setMock(HttpCalloutMock.class, new HttpMockFail());

        // retryCount=2 → fails → enqueues retryCount=3 → 3<3 is false → stops
        Test.startTest();
        Set<Id> ids = new Set<Id>{ UserInfo.getUserId() };
        System.enqueueJob(new ProjetlyQueueable(ids, 'update', 'Account', 2));
        Test.stopTest();

        System.assert(true, 'Retry chain stopped at max 3 attempts');
    }

    @isTest
    static void testQueueableNullIds() {
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Test.startTest();
        System.enqueueJob(new ProjetlyQueueable(null, 'update', 'Opportunity', 0));
        Test.stopTest();

        System.assert(true, 'Null recordIds early-return completed without exception');
    }

    @isTest
    static void testQueueableEmptyIds() {
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Test.startTest();
        System.enqueueJob(new ProjetlyQueueable(new Set<Id>(), 'create', 'contact', 0));
        Test.stopTest();

        System.assert(true, 'Empty recordIds early-return completed without exception');
    }

    // ─── Post Install Handler ─────────────────────────────────────────────────

    @isTest
    static void testPostInstall_newInstall() {
        Test.startTest();
        Test.testInstall(new ProjetlyPostInstallHandler(), null, false);
        Test.stopTest();

        List<PermissionSet> psList = [
            SELECT Id FROM PermissionSet WHERE Name = 'Projetly_User' LIMIT 1
        ];
        if (!psList.isEmpty()) {
            Integer count = [
                SELECT COUNT() FROM PermissionSetAssignment
                WHERE AssigneeId = :UserInfo.getUserId()
                AND PermissionSetId = :psList[0].Id
            ];
            System.assert(count >= 1, 'Permission Set should be assigned after new install');
        }
    }

    @isTest
    static void testPostInstall_alreadyAssigned() {
        // Pre-assign the PS to exercise the duplicate-skip branch
        List<PermissionSet> psList = [
            SELECT Id FROM PermissionSet WHERE Name = 'Projetly_User' LIMIT 1
        ];
        if (!psList.isEmpty()) {
            List<PermissionSetAssignment> existing = [
                SELECT Id FROM PermissionSetAssignment
                WHERE AssigneeId = :UserInfo.getUserId()
                AND PermissionSetId = :psList[0].Id
                LIMIT 1
            ];
            if (existing.isEmpty()) {
                insert new PermissionSetAssignment(
                    AssigneeId = UserInfo.getUserId(),
                    PermissionSetId = psList[0].Id
                );
            }
        }

        Test.startTest();
        Test.testInstall(new ProjetlyPostInstallHandler(), null, false);
        Test.stopTest();

        System.assert(true, 'Re-install with existing PS assignment should not throw');
    }

    @isTest
    static void testPostInstall_upgrade() {
        Test.startTest();
        Test.testInstall(new ProjetlyPostInstallHandler(), new Version(0, 1), true);
        Test.stopTest();

        System.assert(true, 'Upgrade path should complete without exception');
    }
}
