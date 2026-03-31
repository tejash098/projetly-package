trigger OpportunityTrigger on Opportunity (
    after insert, after update, after delete
) {

    Set<Id> oppIds = new Set<Id>();
    String type;

    if (Trigger.isDelete) {
        for (Opportunity o : Trigger.old) oppIds.add(o.Id);
        type = 'delete';
    } else {
        for (Opportunity o : Trigger.new) oppIds.add(o.Id);
        type = Trigger.isInsert ? 'create' : 'update';
    }

    if (!oppIds.isEmpty()) {
        System.enqueueJob(new ProjetlyQueueable(oppIds, type, 0));
    }
}