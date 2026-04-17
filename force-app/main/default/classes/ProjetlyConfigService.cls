// Reads the packaged signing secret from the protected Custom Metadata Type.
// Projetly_Webhook_Config__mdt is visibility:Protected so subscriber orgs
// cannot query or access the record or field value.
public class ProjetlyConfigService {

    public static String getSecret() {
        Projetly_Webhook_Config__mdt cfg = Projetly_Webhook_Config__mdt.getInstance('Default_Config');

        if (cfg == null || String.isBlank(cfg.Secret__c)) {
            throw new AuraHandledException('Missing Projetly secret configuration');
        }

        return cfg.Secret__c;
    }
}