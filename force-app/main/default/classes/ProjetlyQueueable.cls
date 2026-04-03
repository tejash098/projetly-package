public class ProjetlyQueueable implements Queueable, Database.AllowsCallouts {

    @TestVisible static Boolean skipRetry = false;

    private Set<Id> recordIds;
    private String triggerType;
    private String objectType;
    private Integer retryCount;

    public ProjetlyQueueable(Set<Id> recordIds, String triggerType, String objectType, Integer retryCount) {
        this.recordIds = recordIds;
        this.triggerType = triggerType;
        this.objectType = objectType;
        this.retryCount = retryCount;
    }

    public void execute(QueueableContext context) {

        if (recordIds == null || recordIds.isEmpty()) return;

        Set<Id> uniqueIds = new Set<Id>(recordIds);

        Boolean success = ProjetlyWebhookService.sendBatch(uniqueIds, triggerType, objectType);

        // retry max 3 times
        if (!success && retryCount < 3 && !skipRetry) {
            System.enqueueJob(
                new ProjetlyQueueable(uniqueIds, triggerType, objectType, retryCount + 1)
            );
        }
    }
}
