# Example for typescript node application and deploy to Azure AppService with terraform

both infra and application will deploy via terraform by applicaiton will use `null_resource` to build app and use `archive_file` to zip application and last step use `null_resource` to deploy_zip again with `az cli`