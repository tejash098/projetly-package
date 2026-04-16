// Reads the packaged secret from the protected Custom Metadata Type.
// The record is marked protected so subscriber orgs cannot query or read the value.
public class ProjetlyConfigService {

    public static String getSecret() {
        Projetly_Config__mdt config = Projetly_Config__mdt.getInstance('Default');

        if (config == null || String.isBlank(config.Secret__c)) {
            throw new IllegalStateException('Missing Projetly secret configuration');
        }

        return config.Secret__c;
    }
}
