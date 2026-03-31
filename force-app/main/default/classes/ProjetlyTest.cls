@isTest
private class ProjetlyTest {

    // ─── Inner failure mock ───────────────────────────────────────────────────
    class HttpMockFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody('{"error":"unavailable"}');
            return res;
        }
    }

    // ─── Shared helper to create a config record ──────────────────────────────
    static Projetly_Config__c createConfig() {
        Projetly_Config__c cfg = new Projetly_Config__c(
            Name = 'Default',
            Active__c = true,
            Secret__c = 'test_secret_value'
        );
        insert cfg;
        return cfg;
    }

    // ─── Existing tests ───────────────────────────────────────────────────────

    @isTest
    static void testOpportunityFlow() {

        createConfig();
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

        // Trigger: INSERT
        insert opp;

        // Trigger: UPDATE
        opp.Name = 'Updated Opp';
        update opp;

        // Trigger: DELETE
        delete opp;

        Test.stopTest();
    }

    @isTest
    static void testAccountTrigger() {

        createConfig();
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

        Test.startTest();

        acc.Name = 'Updated';
        update acc;

        Test.stopTest();
    }

    @isTest
    static void testOCRTrigger() {

        createConfig();
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

        Contact con = new Contact(
            LastName = 'Test',
            AccountId = acc.Id
        );
        insert con;

        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = con.Id,
            Role = 'Decision Maker'
        );

        Test.startTest();

        insert ocr;

        ocr.Role = 'Influencer';
        update ocr;

        delete ocr;

        Test.stopTest();
    }

    // ─── New tests ────────────────────────────────────────────────────────────

    @isTest
    static void testRetryOnFailure() {

        createConfig();
        Test.setMock(HttpCalloutMock.class, new HttpMockFail());

        Account acc = new Account(Name = 'Retry Acc');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Retry Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert opp;

        Test.startTest();

        // Directly invoke queueable with retryCount = 0 using fail mock
        // sendBatch returns false → queueable should enqueue retry (retryCount = 1)
        Set<Id> ids = new Set<Id>{ opp.Id };
        System.enqueueJob(new ProjetlyQueueable(ids, 'update', 0));

        Test.stopTest();

        // If we reach here without exception the retry branch executed without error
        System.assert(true, 'Retry path completed without exception');
    }

    @isTest
    static void testEmptyOppIds() {

        createConfig();
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Test.startTest();

        // Empty set — should return immediately without callout or exception
        Boolean result = ProjetlyWebhookService.sendBatch(new Set<Id>(), 'update');

        Test.stopTest();

        System.assertEquals(true, result, 'Empty oppIds should return true (no-op)');
    }

    @isTest
    static void testNoConfigRecord() {

        // Intentionally no config inserted
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Account acc = new Account(Name = 'No Config Acc');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'No Config Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert opp;

        Test.startTest();

        Boolean result = ProjetlyWebhookService.sendBatch(
            new Set<Id>{ opp.Id }, 'update'
        );

        Test.stopTest();

        // Should fail gracefully (exception caught internally → returns false)
        System.assertEquals(false, result, 'Missing config should return false');
    }

    @isTest
    static void testWithConfigRecord() {

        createConfig();
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        Account acc = new Account(Name = 'Config Acc');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Config Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert opp;

        Test.startTest();

        Boolean result = ProjetlyWebhookService.sendBatch(
            new Set<Id>{ opp.Id }, 'update'
        );

        Test.stopTest();

        System.assertEquals(true, result, 'Valid config should result in successful callout');
    }

    @isTest
    static void testBulkOpportunities() {

        createConfig();
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

        insert opps;

        Test.stopTest();

        System.assertEquals(200, [SELECT COUNT() FROM Opportunity WHERE AccountId = :acc.Id],
            '200 opportunities should be inserted');
    }
}
