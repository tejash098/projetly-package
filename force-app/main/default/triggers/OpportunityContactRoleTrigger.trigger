trigger OpportunityContactRoleTrigger on OpportunityContactRole (
    after insert, after update, after delete
) {

    Set<Id> contactIds = new Set<Id>();
    String triggerType;

    if (Trigger.isDelete) {
        for (OpportunityContactRole ocr : Trigger.old) {
            if (ocr.ContactId != null) contactIds.add(ocr.ContactId);
        }
        triggerType = 'delete';
    } else if (Trigger.isInsert) {
        for (OpportunityContactRole ocr : Trigger.new) {
            if (ocr.ContactId != null) contactIds.add(ocr.ContactId);
        }
        triggerType = 'create';
    } else {
        for (OpportunityContactRole ocr : Trigger.new) {
            if (ocr.ContactId != null) contactIds.add(ocr.ContactId);
        }
        triggerType = 'update';
    }

    if (!contactIds.isEmpty()) {
        try {
            System.enqueueJob(new ProjetlyQueueable(contactIds, triggerType, 'contact', 0));
        } catch (System.AsyncException e) {
            System.debug(LoggingLevel.WARN, 'OpportunityContactRoleTrigger: enqueue failed - ' + e.getMessage());
        }
    }
}
