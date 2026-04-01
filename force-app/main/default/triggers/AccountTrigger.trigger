trigger AccountTrigger on Account (after insert, after update, after delete) {

    Set<Id> accountIds = new Set<Id>();
    String triggerType;

    if (Trigger.isDelete) {
        for (Account acc : Trigger.old) accountIds.add(acc.Id);
        triggerType = 'delete';
    } else if (Trigger.isInsert) {
        for (Account acc : Trigger.new) accountIds.add(acc.Id);
        triggerType = 'create';
    } else {
        for (Account acc : Trigger.new) accountIds.add(acc.Id);
        triggerType = 'update';
    }

    if (!accountIds.isEmpty()) {
        System.enqueueJob(new ProjetlyQueueable(accountIds, triggerType, 'Account', 0));
    }
}
