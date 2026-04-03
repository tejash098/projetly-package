trigger OpportunityContactRoleTrigger on OpportunityContactRole (
    after insert, after update, after delete
) {

    Set<Id> oppIds = new Set<Id>();

    if (Trigger.isDelete) {
        for (OpportunityContactRole ocr : Trigger.old) {
            if (ocr.OpportunityId != null) oppIds.add(ocr.OpportunityId);
        }
    } else {
        for (OpportunityContactRole ocr : Trigger.new) {
            if (ocr.OpportunityId != null) oppIds.add(ocr.OpportunityId);
        }
    }

    if (!oppIds.isEmpty()) {
        try {
            System.enqueueJob(new ProjetlyQueueable(oppIds, 'update', 'Opportunity', 0));
        } catch (System.AsyncException e) {
            System.debug(LoggingLevel.WARN, 'OpportunityContactRoleTrigger: enqueue failed - ' + e.getMessage());
        }
    }
}
