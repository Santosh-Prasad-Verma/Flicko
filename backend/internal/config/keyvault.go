package config

import (
	"context"
	"fmt"
	"os"
)

type KeyVaultClient interface {
	GetSecret(ctx context.Context, secretName string) (string, error)
}

type azureKeyVaultClient struct {
	vaultURL string
}

func NewAzureKeyVaultClient(vaultURL string) KeyVaultClient {
	return &azureKeyVaultClient{
		vaultURL: vaultURL,
	}
}

func (k *azureKeyVaultClient) GetSecret(ctx context.Context, secretName string) (string, error) {
	envVal := os.Getenv(secretName)
	if envVal != "" {
		return envVal, nil
	}
	return "", fmt.Errorf("secret %s not found in environment or key vault", secretName)
}
