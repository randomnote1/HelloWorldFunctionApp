# Deploy to Azure

1. Select the Azure Cloud

    ```powershell
    az cloud set --name AzureCloud
    ```

1. Log into Azure

    ```powershell
    az login
    ```

1. Select the Azure subscription

    ```powershell
    az account set --subscription <subscription name>
    ```

1. Set the working directory to the main module directory

    ```powershell
    Set-Location -Path .\src\Infrastructure\main
    ```

1. Initialize terraform

    ```powershell
    terraform init -reconfigure
    ```

1. Apply the terraform configuration

    ```powershell
    terraform apply -var-file="..\Environments\<environment name>.tfvars"
    ```
