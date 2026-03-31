trigger AccountTrigger on Account (after update) {

    Set<Id> accountIds = new Set<Id>();

    for (Account acc : Trigger.new) {
        Account old = Trigger.oldMap.get(acc.Id);
        if (
            acc.Name != old.Name ||
            acc.Description != old.Description ||
            acc.BillingCountry != old.BillingCountry ||
            acc.Industry != old.Industry ||
            acc.Type != old.Type ||
            acc.Website != old.Website
        ) {
            accountIds.add(acc.Id);
        }
    }

    if (accountIds.isEmpty()) return;

    Set<Id> oppIds = new Set<Id>();

    for (Opportunity opp : [
        SELECT Id FROM Opportunity WHERE AccountId IN :accountIds
    ]) {
        oppIds.add(opp.Id);
    }

    if (!oppIds.isEmpty()) {
        System.enqueueJob(new ProjetlyQueueable(oppIds, 'update', 0));
    }
}