public class ProjetlyQueueable implements Queueable, Database.AllowsCallouts {

    private Set<Id> oppIds;
    private String triggerType;
    private Integer retryCount;

    public ProjetlyQueueable(Set<Id> oppIds, String triggerType, Integer retryCount) {
        this.oppIds = oppIds;
        this.triggerType = triggerType;
        this.retryCount = retryCount;
    }

    public void execute(QueueableContext context) {

        if (oppIds == null || oppIds.isEmpty()) return;

        Set<Id> uniqueIds = new Set<Id>(oppIds);

        Boolean success = ProjetlyWebhookService.sendBatch(uniqueIds, triggerType);

        // retry max 3 times
        if (!success && retryCount < 3) {
            System.enqueueJob(
                new ProjetlyQueueable(uniqueIds, triggerType, retryCount + 1)
            );
        }
    }
}