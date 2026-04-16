trigger ContactTrigger on Contact (after insert, after update, after delete) {

    Set<Id> contactIds = new Set<Id>();
    String triggerType;

    if (Trigger.isDelete) {
        for (Contact con : Trigger.old) contactIds.add(con.Id);
        triggerType = 'delete';
    } else if (Trigger.isInsert) {
        for (Contact con : Trigger.new) contactIds.add(con.Id);
        triggerType = 'create';
    } else {
        for (Contact con : Trigger.new) contactIds.add(con.Id);
        triggerType = 'update';
    }

    if (!contactIds.isEmpty()) {
        try {
            System.enqueueJob(new ProjetlyQueueable(contactIds, triggerType, 'contact', 0));
        } catch (System.AsyncException e) {
            System.debug(LoggingLevel.WARN, 'ContactTrigger: enqueue failed - ' + e.getMessage());
        }
    }
}
