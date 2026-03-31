trigger AccountTrigger on Account (after update) {

    Set<Id> accountIds = new Set<Id>();

    for (Account acc : Trigger.new) {
        accountIds.add(acc.Id);
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