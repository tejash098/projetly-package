trigger ContactTrigger on Contact (after insert, after update, after delete) {

    Set<Id> accountIds = new Set<Id>();

    if (Trigger.isDelete) {
        for (Contact con : Trigger.old) {
            if (con.AccountId != null) accountIds.add(con.AccountId);
        }
    } else {
        for (Contact con : Trigger.new) {
            if (con.AccountId != null) accountIds.add(con.AccountId);
        }
    }

    if (!accountIds.isEmpty()) {
        try {
            System.enqueueJob(new ProjetlyQueueable(accountIds, 'update', 'Account', 0));
        } catch (System.AsyncException e) {
            System.debug(LoggingLevel.WARN, 'ContactTrigger: enqueue failed - ' + e.getMessage());
        }
    }
}
