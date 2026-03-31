@isTest
private class ProjetlyTest {

    @isTest
    static void testOpportunityFlow() {

        // Mock HTTP callout
        Test.setMock(HttpCalloutMock.class, new ProjetlyHttpMock());

        // Create test data
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
}