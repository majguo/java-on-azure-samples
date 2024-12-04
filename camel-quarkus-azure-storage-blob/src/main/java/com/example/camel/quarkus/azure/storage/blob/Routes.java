package com.example.camel.quarkus.azure.storage.blob;

import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.storage.blob.BlobServiceClient;
import com.azure.storage.blob.BlobServiceClientBuilder;
import jakarta.enterprise.context.ApplicationScoped;
import org.apache.camel.builder.RouteBuilder;
import org.apache.commons.io.IOUtils;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;

import org.jboss.logging.Logger;

/**
 * camel azure-storage-blob routes.
 */
@ApplicationScoped
public class Routes extends RouteBuilder {

    private static final Logger LOG = Logger.getLogger(Routes.class);

    @ConfigProperty(name = "azure.storage.blob.endpoint")
    String endpoint;

    @ConfigProperty(name = "account.name")
    String accountName;

    @ConfigProperty(name = "container.name")
    String containerName;

    @ConfigProperty(name = "blob.name")
    String blobName;

    @Override
    public void configure() {
        /**
         *  See references:
         *  - https://camel.apache.org/components/4.8.x/azure-storage-blob-component.html#_advanced_azure_storage_blob_configuration
         *  - https://learn.microsoft.com/azure/developer/java/sdk/authentication/azure-hosted-apps#defaultazurecredential
         */
        BlobServiceClient client = new BlobServiceClientBuilder()
                .endpoint(endpoint)
                .credential(new DefaultAzureCredentialBuilder().build())
                .buildClient();
        getContext().getRegistry().bind("client", client);

        fromF("azure-storage-blob://%s/%s?blobName=%s&serviceClient=#client", accountName, containerName, blobName)
                .process(exchange -> {
                    InputStream is = exchange.getMessage().getBody(InputStream.class);
                    LOG.infof("Downloaded blob %s: %s", blobName, IOUtils.toString(is, StandardCharsets.UTF_8));
                })
                .end();
    }
}
